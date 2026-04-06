# Orders & Account Transactions

A Ruby on Rails API demonstrating safe financial state management:
atomic status transitions, balance mutations with database-level locking,
an immutable ledger, and soft deletion across all models.

---

## Table of Contents

- [Domain](#domain)
- [API Endpoints](#api-endpoints)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Swagger UI](#swagger-ui)
- [Design Decisions](#design-decisions)
  - [Pessimistic Locking on Account](#pessimistic-locking-on-account)
  - [Optimistic Locking on Order](#optimistic-locking-on-order)
  - [Immutable Ledger and Soft Delete](#immutable-ledger-and-soft-delete)

---

## Domain

```
User
 ├── has_one  Account          (balance, pessimistic lock)
 ├── has_many Orders           (state machine, optimistic lock)
 └── Orders → has_many AccountTransactions  (immutable ledger)
```

**Order status transitions:**

```text
created ──► success ──► cancelled          (reversal transaction created)
   │          │
   │          └─► refund_requested ──► refund_processing ──► refunded
   │                                          │
   │                                          └─► refund_failed ──► refund_requested (retry)
   └─► cancelled (no financial impact)
```

| Transition | Balance effect |
|------------|----------------|
| `created → success` | Deduct `order.amount` from account |
| `created → cancelled` | No change |
| `success → cancelled` | Return `order.amount` to account (reversal) |
| `success → refund_requested` | No immediate balance change |
| `refund_processing → refunded` | Return `order.amount` to account |
| `refund_failed → refund_requested` | No balance change (retry) |

---

| Method | Path | Description |
|--------|------|-------------|
| `POST`  | `/api/v1/users/:user_id/orders` | Create order |
| `GET`   | `/api/v1/users/:user_id/orders` | List orders |
| `GET`   | `/api/v1/users/:user_id/orders/:id` | Get order |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/complete` | Complete order |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/cancel` | Cancel order |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/request_refund` | Request refund |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/retry_refund` | Retry failed refund |
| `GET`   | `/api/v1/users/:user_id/account` | Get balance |
| `GET`   | `/api/v1/users/:user_id/account/transactions` | Ledger history |

---

## Infrastructure

The application is fully containerized and includes:
- **PostgreSQL 16**: Primary storage for orders, accounts, and transactions.
- **Kafka & Zookeeper**: Event streaming backbone (Kafka 7.5.0).

## Requirements

- Docker 24+
- Docker Compose v2
- Kafka (included in docker-compose)

---

## Getting Started

```bash
git clone https://github.com/gushul/laughing-octo-adventure.git
cd laughing-octo-adventure

```

Then run everything in one command:

```bash
make start
```

This runs the following steps in order:

```
make build     →  docker compose build
make db-setup  →  docker compose run --rm web bin/rails db:setup
make db-seed   →  docker compose run --rm web bin/rails db:seed
make up        →  docker compose up
```

The app will be available at `http://localhost:3000`.

Migrations run automatically on every `docker compose up` via
the built-in Rails entrypoint `bin/docker-entrypoint` —
no manual migration step needed after the initial setup.

### Individual commands

```bash
make build      # build Docker images
make db-setup   # create database and run migrations
make db-seed    # seed database with sample data
make up         # start containers
```

---

## Running Tests

```bash
docker compose run --rm web bundle exec rspec
```

---

## Testing with curl

User and account are created by `db:seed` — no registration endpoint exists.
Use `USER_ID=1` (seeded user) for all requests.

### Check account balance

```bash
curl -s http://localhost:3000/api/v1/users/1/account | jq
```

### Create an order

```bash
curl -s -X POST http://localhost:3000/api/v1/users/1/orders \
  -H "Content-Type: application/json" \
  -d '{"amount": 49.99, "description": "Test order"}' | jq
```

### Complete the order (deducts balance)

```bash
curl -s -X PATCH http://localhost:3000/api/v1/users/1/orders/1/complete | jq
```

### Request a refund

```bash
curl -s -X PATCH http://localhost:3000/api/v1/users/1/orders/1/request_refund | jq
```

### Retry a failed refund

```bash
curl -s -X PATCH http://localhost:3000/api/v1/users/1/orders/1/retry_refund | jq
```

### View ledger — all charges and reversals

```bash
curl -s http://localhost:3000/api/v1/users/1/account/transactions | jq
```

### Full flow in one script

```bash
BASE="http://localhost:3000/api/v1/users/1"

# Check initial balance
curl -s $BASE/account | jq '.balance'

# Create order
ORDER=$(curl -s -X POST $BASE/orders \
  -H "Content-Type: application/json" \
  -d '{"amount": 49.99}')
ORDER_ID=$(echo $ORDER | jq '.id')
echo "Order $ORDER_ID created"

# Complete order — balance deducted
curl -s -X PATCH $BASE/orders/$ORDER_ID/complete | jq '{status, amount}'
curl -s $BASE/account | jq '.balance'

# Request refund
curl -s -X PATCH $BASE/orders/$ORDER_ID/request_refund | jq '{status}'

# Retry refund
curl -s -X PATCH $BASE/orders/$ORDER_ID/retry_refund | jq '{status}'

# Ledger — shows charge + refund
curl -s $BASE/account/transactions | jq '[.[] | {kind, amount}]'
```

Expected ledger output after the full flow:

```json
[
  { "kind": "refund",   "amount":  49.99 },
  { "kind": "charge",   "amount": -49.99 }
]
```

> `jq` is optional — remove it if not installed. Responses are plain JSON.


---

## Swagger UI

```bash
docker compose run --rm web bundle exec rails rswag
```

Open `http://localhost:3000/api-docs`.

---

## Design Decisions

### Pessimistic Locking on Account

When an order is completed or cancelled the account balance must be read
and written atomically. Without a lock two concurrent requests can both
read the same balance, both pass the "sufficient funds" check, and both
deduct — resulting in a negative balance:

```
Request A reads balance: $100  ✓ sufficient
Request B reads balance: $100  ✓ sufficient
Request A deducts $100  →  balance: $0
Request B deducts $100  →  balance: -$100  ← overdraft
```

We prevent this with a pessimistic lock (`SELECT FOR UPDATE`):

```ruby
# app/services/orders/complete_service.rb
account = @order.user.account.lock!
```

`lock!` blocks the row until the transaction commits. Request B waits,
then reads the updated balance of $0 and correctly raises
`InsufficientFundsError`.

Pessimistic locking is the right choice here because:
- Balance contention is **expected** — every order completion touches it
- We must read the **current value** before we can validate it
- The lock scope is narrow — one row, inside a short transaction

See [`app/services/orders/complete_service.rb`](app/services/orders/complete_service.rb)
and [`app/services/orders/cancel_service.rb`](app/services/orders/cancel_service.rb).

---

### Optimistic Locking on Order

The typical race on an order is two Sidekiq workers or two API calls both
trying to complete the same order simultaneously.

We protect against this with optimistic locking via a `lock_version` column.
Rails automatically appends `AND lock_version = N` to every UPDATE:

```sql
UPDATE orders
SET status = 'success', lock_version = 1
WHERE id = 42 AND lock_version = 0
```

If two workers both read `lock_version = 0`, only one UPDATE affects a row.
The other gets 0 rows updated and Rails raises `ActiveRecord::StaleObjectError`,
which the service catches and returns as a retriable error.

Optimistic locking is appropriate here because:
- Concurrent transitions on the **same order** are rare
- No row is held locked while the request is in flight
- A clear error and retry is the correct response to the conflict

---


### Immutable Ledger and Soft Delete

`AccountTransaction` records are append-only. Once written they can never
be updated or hard-deleted. This is enforced at the model level:

```ruby
before_update  :guard_immutability   # allows only deleted_at to change
before_destroy { raise ImmutableRecordError }
```

All four models support soft deletion via a `deleted_at` column and a
shared `SoftDeletable` concern. Records are never physically removed —
they are hidden from the default scope but remain queryable via
`Model.only_deleted` or `Model.with_deleted`.
### Audit Logging & Outbox Pattern

Every transaction and state change is recorded in the `AuditLog` table:
- **Traceability**: All logs include `user_id` attribution, `ip_address`, and `user_agent`.
- **Atomic Persistence**: Audit logs are created within the same DB transaction as the balance mutation.
- **Reliable Dispatch**: Every audit log triggers an `OutboxEvent` of type `audit_log_created`.
- **Event-Driven**: The `OutboxJob` periodically picks up pending events and publishes them to Kafka (if configured), ensuring **at-least-once** delivery to downstream consumers (ClickHouse, external APIs).

Each `audit_log_created` payload contains the full audit log as JSON, including before/after state changes of the affected entity.

---

### Ledger Reconciliation

To prevent data corruption, every balance-modifying service (`CompleteService`, `CancelService`, `ProcessRefundService`) performs a real-time reconciliation check:
- It locks the account row.
- It sums all `account_transactions` from the database.
- It compares the sum against the cached `account.balance_cents`.
- If a discrepancy is found, the operation fails and triggers an alert.

This ensures that the account balance is always backed by an immutable chain of transactions.

For `AccountTransaction`, soft delete is the only permitted mutation:
the guard allows `deleted_at` to change while rejecting any change to
financial fields such as `amount_cents` or `kind`.

Cancellation is always a new `reversal` entry — never an edit to the
original `charge`. This preserves a full audit trail and satisfies
accounting requirements without special tooling.



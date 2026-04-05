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
  - [Can We Test Locking with RSpec?](#can-we-test-locking-with-rspec)
  - [Why No Idempotency Keys](#why-no-idempotency-keys)
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

```
created ──► success ──► cancelled  (reversal transaction created)
   │
   └────────────────────► cancelled  (no financial impact)
```

| Transition | Balance effect |
|------------|---------------|
| `created → success` | Deduct `order.amount` from account |
| `created → cancelled` | No change |
| `success → cancelled` | Return `order.amount` to account (reversal entry) |
| Any `→ cancelled` again | Rejected — `422 Unprocessable Entity` |

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST`  | `/api/v1/users/:user_id/orders` | Create order |
| `GET`   | `/api/v1/users/:user_id/orders` | List orders |
| `GET`   | `/api/v1/users/:user_id/orders/:id` | Get order |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/complete` | Complete order |
| `PATCH` | `/api/v1/users/:user_id/orders/:id/cancel` | Cancel order |
| `GET`   | `/api/v1/users/:user_id/account` | Get balance |
| `GET`   | `/api/v1/users/:user_id/account/transactions` | Ledger history |

---

## Requirements

- Docker 24+
- Docker Compose v2

---

## Getting Started

```bash
git clone https://github.com/gushul/laughing-octo-adventure.git
cd laughing-octo-adventure

cp .env.example .env
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

### Cancel a completed order (creates reversal, returns balance)

```bash
curl -s -X PATCH http://localhost:3000/api/v1/users/1/orders/1/cancel | jq
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

# Cancel order — reversal created, balance restored
curl -s -X PATCH $BASE/orders/$ORDER_ID/cancel | jq '{status}'
curl -s $BASE/account | jq '.balance'

# Ledger — shows charge + reversal
curl -s $BASE/account/transactions | jq '[.[] | {kind, amount}]'
```

Expected ledger output after the full flow:

```json
[
  { "kind": "reversal", "amount":  49.99 },
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

### Can We Test Locking with RSpec?

**Pessimistic lock** — testing real blocking requires two concurrent
database connections, which is not practical in RSpec. Instead we test
the observable outcome: that balance does not go negative and that
atomicity holds when an error is raised mid-transaction:

```ruby
it "rolls back balance if order transition raises" do
  allow_any_instance_of(Order).to receive(:complete!).and_raise(StandardError)
  expect { service.call rescue nil }.not_to change { account.reload.balance_cents }
end
```

**Optimistic lock** — fully testable in RSpec. We increment `lock_version`
directly in the DB while the service object holds the stale in-memory value:

```ruby
it "returns a retriable error on concurrent modification" do
  Order.find(order.id).update_columns(lock_version: order.lock_version + 1)

  result = Orders::CompleteService.new(order: order).call
  expect(result.success?).to be false
  expect(result.error).to match(/modified concurrently/)
end
```

---

### Why No Idempotency Keys

Idempotency keys are essential when the same operation can be retried by
an external caller who does not know whether the first attempt succeeded —
typically in webhook delivery or payment gateway calls.

This project does not need them because:

- All transitions are driven by **explicit user actions** via the API,
  not by background jobs calling external services
- The state machine enforces that `created → success` can happen exactly
  once — a second call returns a clear `422` rather than processing again
- There is no external gateway call that could succeed on the gateway side
  but fail on ours — the entire operation is one local database transaction
- Optimistic locking already handles the concurrency case — exactly one
  of two racing requests wins, the other gets a retriable error

Idempotency keys become necessary the moment an external payment gateway
is introduced.

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

For `AccountTransaction`, soft delete is the only permitted mutation:
the guard allows `deleted_at` to change while rejecting any change to
financial fields such as `amount_cents` or `kind`.

Cancellation is always a new `reversal` entry — never an edit to the
original `charge`. This preserves a full audit trail and satisfies
accounting requirements without special tooling.

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
git clone https://github.com/gushul/orders-api.git
cd orders-api

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
---

## Documentation

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

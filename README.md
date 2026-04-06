## Getting Started

```bash
git clone https://github.com/gushul/fluffy-eureka.git
cd fluffy-eureka.git

```

Запустить в докер одной командой:

```bash
make start
```

Или вызвать по отдельности:

```bash
make build     ->  docker compose build
make db-setup  ->  docker compose run --rm web bin/rails db:prepare
make db-seed   ->  docker compose run --rm web bin/rails db:seed
make up        ->  docker compose up
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



## API Endpoints

Base path: `/api/v1/users/:user_id`

### Orders

| Method | Path | Service | Description |
|--------|------|---------|-------------|
| `GET` | `/orders` | — | List orders |
| `GET` | `/orders/:id` | — | Get order |
| `POST` | `/orders` | — | Create order (status: created) |
| `PATCH` | `/orders/:id/complete` | `CompleteService` | created → success |
| `PATCH` | `/orders/:id/cancel` | `CancelService` | created → cancelled |
| `PATCH` | `/orders/:id/request_refund` | `RequestRefundService` | success → refund_requested |
| `PATCH` | `/orders/:id/retry_refund` | `RetryRefundService` | refund_failed → refund_requested |

### Account

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/account` | Balance |
| `GET` | `/account/transactions` | Ledger history |

### Response format — Order

```json
{
  "id": 1,
  "status": "success",
  "amount": 49.99,
  "description": "Test order",
  "refund_reason": null,
  "refunded_at": null,
  "created_at": "2024-01-01T12:00:00Z",
  "updated_at": "2024-01-01T12:00:01Z"
}
```

### Error format

```json
{ "error": "Insufficient funds: balance 10.0 < order amount 50.0" }
```

### HTTP Status codes

| Situation | Code |
|-----------|------|
| Success | 200 |
| Created | 201 |
| Invalid transition / business rule | 422 |
| Record not found | 404 |
| Concurrent modification | 422 |

---

# Flow

## Domain

```
User
 ├── has_one   Account
 ├── has_many  Orders
 └── has_many  AuditLogs (as actor)

Account
 ├── belongs_to  User
 └── has_many    AccountTransactions      <- immutable ledger

Order
 ├── belongs_to  User
 └── has_many    AccountTransactions

AccountTransaction                       <- append-only, no update/delete
 ├── belongs_to  Account
 └── belongs_to  Order

DomainEvent                              <- внутренняя шина
 └── belongs_to  source (polymorphic)   <- триггер для подписчиков внутри Rails

OutboxEvent                              <- внешняя шина
 └── (no associations)                  <- Kafka -> ClickHouse, другие сервисы

AuditLog                                 <- compliance trail, 2 месяца в Postgres
 ├── belongs_to  actor (polymorphic)    <- User | System
 └── belongs_to  auditable (polymorphic) <- Order | Account
```

# Паттерны которые реализованы в проекте:

## State Machine

### Order

```
                    ┌─────────────────────────────────────┐
                    │                                     ▼
[created] ──complete!──► [success] ──request_refund!──► [refund_requested]
    │                                                        │
    └──cancel!──► [cancelled]              start_refund_processing!
                                                        │
                                               [refund_processing]
                                                   │         │
                                         complete_refund! fail_refund!
                                                   │         │
                                              [refunded] [refund_failed]
                                                             │
                                                       retry_refund!
                                                             │
                                                   [refund_requested] (retry)
```

| Event | From | To | Balance effect |
|-------|------|----|----------------|
| `complete!` | created | success | `-= amount` |
| `cancel!` | created | cancelled | none |
| `request_refund!` | success | refund_requested | none |
| `start_refund_processing!` | refund_requested | refund_processing | none |
| `complete_refund!` | refund_processing | refunded | `+= amount` |
| `fail_refund!` | refund_processing | refund_failed | rollback |
| `retry_refund!` | refund_failed | refund_requested | none |

---

## Event System

### Полная картина одной транзакции

```
CompleteService (одна DB транзакция)
 ├── AccountTransaction.create!   ← финансовая запись (immutable ledger)
 ├── AuditLog.create!             ← кто/что/до/после (compliance, 60 дней)
 ├── DomainEvent.create!          ← внутренние подписчики Rails
 └── OutboxEvent.create!          ← Kafka → ClickHouse (навсегда)
```

### Event Types

| Event | DomainEvent subscribers | OutboxEvent → Kafka topic |
|-------|------------------------|--------------------------|
| `order.completed` | Notification, Reconciliation | `order.completed` |
| `order.cancelled` | Notification | `order.cancelled` |
| `order.refund_requested` | Notification, RefundWorkflow | `order.refund_requested` |
| `order.refunded` | Notification, Reconciliation | `order.refunded` |
| `order.refund_failed` | Notification, Alert | `order.refund_failed` |
| `order.refund_retried` | Notification | `order.refund_retried` |

---
## DomainEvent + Subscribe


Все подписчики — stateless callable объекты: `SubscriberClass.call(payload)`.  
Вызываются из `DomainEventProcessorJob`.  
При ошибке — пробрасывают исключение чтобы job пометил event как `failed`.

### Idempotency

Все подписчики должны быть idempotent.

Требования:

- повторный вызов не должен создавать дубликаты
- внешние side-effects (email, webhook) должны быть защищены

Рекомендуемые подходы:

- хранить processed_event_ids
- использовать unique constraints
- делать операции idempotent по payload

---

## AuditLog + Outbox
PCI DSS

AuditLog - за два месяца, текущая партиция - Postgres, всегда - ClickHouse(по нормативу 12 месяцев)

CompleteService (одна транзакция)
  ├── AuditLog.create!       <- Postgres, партиция текущего месяца
  └── OutboxEvent.create!    <- Postgres, outbox таблица

                    ⬇️ (каждые 30 сек)

OutboxJob
  ├── SELECT ... FOR UPDATE SKIP LOCKED  <- батч 100 событий
  ├── GenericProducer.deliver(topic: "audit_logs", event:)
  ├── GenericProducer.flush              <- батчевая отправка в Kafka
  └── update_all(processed_at: now)     <- только успешно доставленные

                    ⬇️

Kafka topic: "audit_logs"

                    ⬇️

ClickHouse ← хранит навсегда
  audit_logs table (весь исторический архив)

                    ⬇️ (в начале каждого месяца)

По крону удаляем старую (позапрошлого месяца) партицию(DROP TABLE) в Postgres, данные уже в ClickHouse.
И создаем новую партицию для сл. месяца(не текущего).


---
## Idempotency key:
  Запрос 1: Idempotency-Key: "abc-123"
    -> find_by("abc-123") → nil
    -> yield → выполняем CompleteService
    -> сохраняем результат в IdempotencyKey
    -> возвращаем result

  Запрос 2 (retry клиента): Idempotency-Key: "abc-123"
    -> find_by("abc-123") → НАШЛИ
    -> возвращаем сохранённый результат
    -> бизнес-логика НЕ выполняется

  Посмотреть импелментацию [`app/services/base_service.rb`](app/services/base_service.rb)
  Посмотреть использование [`app/services/orders/complete_service.rb`](app/services/orders/complete_service.rb)

Flow

POST /orders/1/complete
  Idempotency-Key: "uuid-123"
         |
  OrdersController#complete
         |
  CompleteService.call(order:, actor:, idempotency_key: "uuid-123")
         |
  with_idempotency("uuid-123")
    -> find_by -> nil (первый раз)
    -> yield -> бизнес-логика
    -> сохранить в IdempotencyKey
    -> вернуть Result
         |
  render_result(result)

POST /orders/1/complete (retry клиента, сеть моргнула)
  Idempotency-Key: "uuid-123"
         |
  with_idempotency("uuid-123")
    -> find_by -> НАШЛИ
    -> вернуть сохранённый Result
    -> бизнес-логика НЕ выполняется
    -> деньги НЕ списываются повторно


---
## Immutable Ledger + Soft Delete

AccountTransaction можно только записать. 
AccountTransaction никогда нельзя обновить или удалить полностью. Это обеспечивается на уровне модели:

```ruby
before_update :guard_immutability # позволяет изменять только `deleted_at`
before_destroy { raise ImmutableRecordError }
```

Бизнес модели поддерживают мягкое удаление через столбец `deleted_at`


---
## Ledger Reconciliation

Все сервисы, меняющие баланс (`CompleteService`, `CancelService`, `ProcessRefundService`), делают реальную сверку:

* Блокируют строку аккаунта
* Суммируют `account_transactions`
* Сравнивают с `account.balance_cents`
* При расхождении — операция падает и отправляется алерт

```ruby
ledger_sum = account.account_transactions.reload.sum(:amount_cents)
if account.balance_cents != ledger_sum
  return failure("Balance discrepancy detected: account=#{account.balance_cents}, ledger=#{ledger_sum}")
end

```

Баланс всегда подкреплен неизменяемой цепочкой транзакций.

`AccountTransaction` — только append-only (кроме `deleted_at`). Изменение финансовых полей (`amount_cents`, `kind`) запрещено.

Отмена всегда создаёт новый `reversal`, оригинальный `charge` не меняется — полный аудиторский след и бухгалтерская целостность.


## Locking strategy

| Resource | Lock type | Reason |
|----------|-----------|--------|
| `Account` | Pessimistic (`lock!`) | Баланс читается до валидации - нельзя работать с устаревшим значением |
| `Order` | Optimistic (`lock_version`) | Конфликт редкий - двойная обработка одного заказа |
| `OutboxEvent` | `FOR UPDATE SKIP LOCKED` | Несколько воркеров без конфликтов |


require "swagger_helper"

RSpec.describe "Api::V1::Orders", type: :request do
  let(:user) { create(:user) }

  before do
    top_up_balance(user.account, 20_000)
    create_list(:order, 2, user: user)
  end

  path "/api/v1/users/{user_id}/orders" do
    parameter name: :user_id, in: :path, type: :integer, required: true

    get "List all orders" do
      tags "Orders"
      produces "application/json"

      response "200", "orders listed" do
        let(:user_id) { user.id }
        schema type: :array, items: { "$ref" => "#/components/schemas/Order" }
        run_test!
      end

      response "404", "user not found" do
        let(:user_id) { 0 }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end

    post "Create an order" do
      tags "Orders"
      consumes "application/json"
      produces "application/json"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount:      { type: :number, example: 49.99 },
          description: { type: :string, example: "Order #1" },
        },
        required: [ :amount ],
      }

      response "201", "order created" do
        let(:user_id) { user.id }
        let(:body) { { amount: 49.99, description: "Test order" } }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "422", "invalid params" do
        let(:user_id) { user.id }
        let(:body) { { amount: -10 } }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/orders/{id}" do
    parameter name: :user_id, in: :path, type: :integer, required: true
    parameter name: :id,      in: :path, type: :integer, required: true

    get "Get an order" do
      tags "Orders"
      produces "application/json"

      response "200", "order found" do
        let(:user_id) { user.id }
        let(:id) { create(:order, user: user).id }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "404", "order not found" do
        let(:user_id) { user.id }
        let(:id) { 0 }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/orders/{id}/complete" do
    parameter name: :user_id, in: :path, type: :integer, required: true
    parameter name: :id,      in: :path, type: :integer, required: true

    patch "Complete an order" do
      tags "Orders"
      produces "application/json"
      description "Transitions order from **created** to **success** and deducts balance"

      # Reference shared Idempotency-Key header from components/parameters
      parameter "$ref" => "#/components/parameters/IdempotencyKey"

      response "200", "order completed" do
        let(:user_id) { user.id }
        let(:id) { create(:order, user: user, amount_cents: 5_000).id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "422", "insufficient funds" do
        let(:user_id) { user.id }
        let(:id) do
          clear_balance(user.account)
          create(:order, user: user, amount_cents: 5_000).id
        end
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end

      response "422", "invalid transition" do
        let(:user_id) { user.id }
        let(:id) { create(:order, :cancelled, user: user).id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/orders/{id}/cancel" do
    parameter name: :user_id, in: :path, type: :integer, required: true
    parameter name: :id,      in: :path, type: :integer, required: true

    patch "Cancel an order" do
      tags "Orders"
      produces "application/json"
      description "Cancels order. If order was **success**, reversal transaction is created."

      parameter "$ref" => "#/components/parameters/IdempotencyKey"

      response "200", "created order cancelled (no financial impact)" do
        let(:user_id) { user.id }
        let(:id) { create(:order, user: user).id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "200", "success order cancelled with reversal" do
        let(:user_id) { user.id }
        let(:id) do
          clear_balance(user.account)
          top_up_balance(user.account, 10_000)

          order = create(:order, :success, user: user, amount_cents: 5_000)

          AccountTransaction.create!(
            account:      user.account,
            order:        order,
            amount_cents: -5_000,
            kind:         "charge"
          )

          user.account.update_column(:balance_cents, 5_000)

          order.id
        end
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "422", "already cancelled" do
        let(:user_id) { user.id }
        let(:id) { create(:order, :cancelled, user: user).id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/orders/{id}/request_refund" do
    parameter name: :user_id, in: :path, type: :integer, required: true
    parameter name: :id,      in: :path, type: :integer, required: true

    patch "Request an order refund" do
      tags "Orders"
      consumes "application/json"
      produces "application/json"
      description "Transitions order from **success** to **refund_requested**"

      parameter "$ref" => "#/components/parameters/IdempotencyKey"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: "Damaged item" }
        },
        required: [ :reason ]
      }

      response "200", "refund requested" do
        let(:user_id) { user.id }
        let(:id) { create(:order, :success, user: user).id }
        let(:body) { { reason: "Customer requested" } }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "422", "invalid transition" do
        let(:user_id) { user.id }
        let(:id) { create(:order, user: user).id }   # created — cannot refund
        let(:body) { { reason: "Customer requested" } }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/orders/{id}/retry_refund" do
    parameter name: :user_id, in: :path, type: :integer, required: true
    parameter name: :id,      in: :path, type: :integer, required: true

    patch "Retry a failed refund" do
      tags "Orders"
      produces "application/json"
      description "Transitions order from **refund_failed** back to **refund_requested**"

      response "200", "refund retried" do
        let(:user_id) { user.id }
        let(:id) { create(:order, :refund_failed, user: user).id }
        schema "$ref" => "#/components/schemas/Order"
        run_test!
      end

      response "422", "invalid transition" do
        let(:user_id) { user.id }
        let(:id) { create(:order, :success, user: user).id }   # not refund_failed
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end
end

require "swagger_helper"

RSpec.describe "Api::V1::Accounts", type: :request do
  let(:user) { create(:user) }

  path "/api/v1/users/{user_id}/account" do
    parameter name: :user_id, in: :path, type: :integer, required: true

    get "Get account balance" do
      tags "Accounts"
      produces "application/json"

      response "200", "account found" do
        let(:user_id) { user.id }
        schema "$ref" => "#/components/schemas/Account"
        run_test!
      end

      response "404", "user not found" do
        let(:user_id) { 0 }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/users/{user_id}/account/transactions" do
    parameter name: :user_id, in: :path, type: :integer, required: true

    get "List account transactions" do
      tags "Accounts"
      produces "application/json"
      description "Immutable ledger — returns all charges and reversals"

      response "200", "transactions listed" do
        let(:user_id) { user.id }
        schema type: :array, items: { "$ref" => "#/components/schemas/Transaction" }
        run_test!
      end
    end
  end
end

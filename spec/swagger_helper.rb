require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.join("swagger").to_s

  config.swagger_docs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Orders API",
        version: "v1",
        description: "API for managing orders and account transactions",
      },
      paths: {},
      components: {
        schemas: {
          Order: {
            type: :object,
            properties: {
              id:          { type: :integer },
              status:      { type: :string, enum: %w[created success cancelled refund_requested refund_processing refunded refund_failed] },
              amount:      { type: :number, format: :float },
              description: { type: :string, nullable: true },
              created_at:  { type: :string, format: "date-time" },
              updated_at:  { type: :string, format: "date-time" },
            },
          },
          Account: {
            type: :object,
            properties: {
              id:         { type: :integer },
              balance:    { type: :number, format: :float },
              updated_at: { type: :string, format: "date-time" },
            },
          },
          Transaction: {
            type: :object,
            properties: {
              id:         { type: :integer },
              kind:       { type: :string, enum: %w[charge reversal] },
              amount:     { type: :number, format: :float },
              order_id:   { type: :integer },
              created_at: { type: :string, format: "date-time" },
            },
          },
          Error: {
            type: :object,
            properties: {
              errors: { type: :array, items: { type: :string } },
            },
          },
        },
        parameters: {
          IdempotencyKey: {
            name: "Idempotency-Key",
            in: :header,
            description: "Idempotency key for safe retries (optional)",
            required: false,
            schema: { type: :string },
          },
        },
      },
    },
  }

  config.swagger_format = :yaml
end

class BaseService
  class Result
    attr_reader :success, :data, :errors

    def initialize(success: true, data: nil, errors: [])
      @success = success
      @data = data
      @errors = errors
    end

    def success? = @success
    def failure? = !@success
    def error; @errors.first; end
  end

  # Class-level entry point
  def self.call(...)
    new(...).call
  end

  # Instance-level entry point (override in subclasses)
  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end

  def with_idempotency(key)
    Thread.current[:disable_ledger_sync] = true
    return yield if key.blank?

    idempotency_key = IdempotencyKey.find_by(key: key)
    if idempotency_key
      # Return saved response
      data = JSON.parse(idempotency_key.response)
      return Result.new(success: data["success"], data: data["data"], errors: data["errors"])
    end

    result = yield

    IdempotencyKey.create!(
      key:      key,
      response: {
        success: result.success?,
        data:    result.data,
        errors:  result.errors,
      }.to_json
    )

    result
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition where two requests with same key arrive at same time
    retry
  ensure
    Thread.current[:disable_ledger_sync] = false
  end

  private

  def success(data = nil)
    Result.new(success: true, data: data)
  end

  def failure(errors = [ "An unexpected error occurred" ])
    Result.new(success: false, errors: Array(errors))
  end
end

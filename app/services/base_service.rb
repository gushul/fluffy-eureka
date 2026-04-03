class BaseService
  class Result
    attr_reader :success?, :data, :errors

    def initialize(success: true, data: nil, errors: [])
      @success = success
      @data = data
      @errors = errors
    end

    def success? = @success
    def failure? = !@success
  end

  # Class-level entry point
  def self.call(...)
    new(...).call
  end

  # Instance-level entry point (override in subclasses)
  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end

  private

  def success(data = nil)
    Result.new(success: true, data: data)
  end

  def failure(errors = [ "An unexpected error occurred" ])
    Result.new(success: false, errors: Array(errors))
  end
end

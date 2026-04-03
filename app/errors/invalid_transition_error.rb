class ApplicationError < StandardError; end
class InsufficientFundsError < ApplicationError; end
class InvalidTransitionError < ApplicationError; end
class ImmutableRecordError < ApplicationError; end

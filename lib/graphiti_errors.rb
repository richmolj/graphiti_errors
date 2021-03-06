require "jsonapi/serializable"

require "graphiti_errors/version"
require "graphiti_errors/exception_handler"
require "graphiti_errors/invalid_request/serializer"
require "graphiti_errors/invalid_request/exception_handler"
require "graphiti_errors/conflict_request/serializer"
require "graphiti_errors/conflict_request/exception_handler"
require "graphiti_errors/validation/serializer"

module GraphitiErrors
  def self.included(klass)
    klass.class_eval do
      class << self
        attr_accessor :_errorable_registry
      end

      def self.inherited(subklass)
        super
        subklass._errorable_registry = _errorable_registry.dup
      end
    end
    klass._errorable_registry = {}
    klass.extend ClassMethods

    if defined?(Graphiti::Errors::InvalidRequest)
      klass.register_exception Graphiti::Errors::InvalidRequest,
        handler: GraphitiErrors::InvalidRequest::ExceptionHandler
    end

    if defined?(Graphiti::Errors::ConflictRequest)
      klass.register_exception Graphiti::Errors::ConflictRequest,
        handler: GraphitiErrors::ConflictRequest::ExceptionHandler
    end
  end

  def self.disable!
    @enabled = false
  end

  def self.enable!
    @enabled = true
  end

  def self.disabled?
    @enabled == false
  end

  def self.logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def handle_exception(e, show_raw_error: false)
    raise e if GraphitiErrors.disabled?

    exception_klass = self.class._errorable_registry[e.class] || default_exception_handler.new
    exception_klass.show_raw_error = show_raw_error
    exception_klass.log(e)
    json   = exception_klass.error_payload(e)
    status = exception_klass.status_code(e)

    render json: json, status: status
  end

  def default_exception_handler
    self.class.default_exception_handler
  end

  def registered_exception?(e)
    self.class._errorable_registry.key?(e.class)
  end

  module ClassMethods
    def register_exception(klass, options = {})
      exception_klass = options[:handler] || default_exception_handler
      _errorable_registry[klass] = exception_klass.new(options)
    end

    def default_exception_handler
      GraphitiErrors::ExceptionHandler
    end
  end

  # Backwards compatibility, as Graphiti 1.0.x references GraphitiErrors::Serializers::Validation
  # where newer versions correctly point to GraphitiErrors::Validation::Serializer
  module Serializers
    Validation = GraphitiErrors::Validation::Serializer
  end
end

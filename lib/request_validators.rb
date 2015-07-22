require 'json'
require 'json-schema'

module RatPackSwagger
  class RequestValidatorCollection
    def initialize
      @validators = {}
    end

    def get(path, verb, type = nil)
      if @validators[path]
        if @validators[path][verb]
          if type
            if @validators[path][verb][type]
              return @validators[path][verb][type]
            end
          else
            return @validators[path][verb]
          end
        end
      end
      return nil
    end

    def set(path, verb, type, validator)
      @validators[path] ||= {}
      @validators[path][verb] ||= {}
      @validators[path][verb][type] = validator
    end
  end

  class JsonBodyValidator
    attr_reader :schema
    def initialize(schema)
      @schema = schema
    end
    def validate(body)
      ::JSON::Validator.validate!(@schema, body)
    end
  end
end

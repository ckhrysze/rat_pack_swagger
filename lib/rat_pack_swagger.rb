require 'sinatra/base'
require 'json'

class SwaggerObject 
  instance_methods.each do |m|
    unless m =~ /^__/ || [:inspect, :instance_eval, :object_id].include?(m)
      undef_method m
    end
  end

  def initialize(*args, **kwargs, &block)
    if args.count > 0 && (!kwargs.empty? || block_given?)
      raise "Cannot give both unnamed arguments AND named arguments or block to Swagger parameter '#{m}'."
    elsif block_given?
      @obj = kwargs unless kwargs.empty?
      instance_eval &block
    elsif !kwargs.empty?
      @obj = kwargs
    elsif args.count > 0
      @obj = [*args]
    else
      raise "Cannot create SwaggerObject with no arguments."
    end
  end

  def add(*args, **kwargs)
    @obj ||= []
    if !@obj.is_a?(Array)
      raise "Swagger object must be an array to append data '#{item}'"
    elsif args.count > 0
      @obj << [*args, kwargs]
    else
      @obj << kwargs
    end
  end

  def method_missing(m, *args, **kwargs, &block)
    @obj ||= {}
    if block_given?
      @obj[m] = SwaggerObject.new(**kwargs, &block).get
    elsif !kwargs.empty?
      @obj[m] = SwaggerObject.new(**kwargs).get
    elsif args.count > 1
      @obj[m] = [*args]
    elsif args.count == 1
      @obj[m] = args[0]
    else
      raise "Cannot give zero arguments to Swagger key '#{m}'"
    end
  end

  def get
    @obj
  end
end

module RatPackSwagger
  module DefinitionClass
    # makes sure @definition is initialized
    def definition
      @definition ||= {
        type: 'object',
        required: [],
        properties: {}
      }
      @definition
    end

    # Class declaration API
    def properties(&block)
      definition[:properties].merge!(SwaggerObject.new(&block).get)
      # create top-level property accessors for instance-like usage
      definition[:properties].keys.each do |k|
        self.send(:attr_accessor, k)
      end
    end
    def required(*args)
      definition[:required].concat([*args]).uniq!
    end
  end

  module Definition
    def self.included mod
      mod.extend DefinitionClass
    end

    def definition
      self.class.definition
    end

    # Instance API
    def validate
      validate_object(definition, to_h(false))
      self
    end
    def from_h(h)
      properties = definition[:properties] 
      h.each do |k,v|
        ksym = k.to_sym
        setter = "#{k}="
        if properties.keys.include?(ksym)
          # if property type references another class, instantiate it and use hash data to populate it
          if properties[ksym][:$ref]
            send(setter, properties[ksym][:$ref].new.from_h(v))
          else
            send("#{k}=", v)
          end
        end
      end
      self
    end
    def to_h(recur = true)
      h = {}
      definition[:properties].keys.each do |p|
        val = send(p)
        if recur && val.respond_to?(:to_h) && (val.to_h != {})
          h[p] = val.to_h
        elsif val
          h[p] = val
        end
      end
      h
    end

    # Validation
    def validate_object(object_definition, data)
      check_requireds(object_definition, data)
      check_object_types(object_definition, data)
    end
    def check_requireds(object_definition, data)
      object_definition[:properties].keys.each do |k|
        if object_definition[:required].include?(k) && data[k].nil?
          raise "Missing required property #{k}"
        end
      end
    end
    def check_object_types(object_definition, data)
      data.each do |k,v|
        property = object_definition[:properties][k]

        # verify 'type' if set
        type = property[:type]
        if type
          case type
          when :string
            raise "Property #{k} must be a string, not a #{v.class}" unless [String, Symbol].include?(v.class)  
          when :number
            raise "Property #{k} must be a number, not a #{v.class}" unless v.is_a?(Numeric) 
          when :integer
            if v.is_a?(Numeric)
              raise "Property #{k} must be an integer. Value is #{v}" unless v % 1 == 0
            else
              raise "Property #{k} must be an integer, not a #{v.class}" unless v.is_a?(Numeric)
            end
          when :boolean
            raise "Property #{k} must be a string, not a #{v.class}" unless [FalseClass, TrueClass].include?(v.class)  
          when :array
            raise "Property #{k} must be an array, not a #{v.class}" unless v.is_a?(Array)
          when :object
            validate_object(property, v)
          else
            raise "Unknown property type '#{type}'"
          end
        end
  
        # verify type if a ref to another definition class
        ref = property[:$ref]
        if ref
          raise "Property #{k} should be a #{ref}, not a #{v.class}" unless ref.to_s == v.class.name
        end

        # verify enum
        enum = property[:enum]
        if enum
          raise "Enum for property #{k} must be an array, not a #{enum.class}" unless enum.is_a?(Array)
          raise "Invalid enum value (#{v}) for property #{k}. Valid enum values are #{enum}" unless enum.include?(v)
        end

        # verify mins and maxes
        min = property[:minimum]
        if min
          raise "Property #{k} value (#{v}) is less than the property minimum (#{min})" unless v >= min
        end
        max = property[:maximum]
        if min
          raise "Property #{k} value (#{v}) is less than the property maximum (#{max})" unless v <= max
        end
      end
    end
  end
end

module Sinatra
  module RatPackSwagger
    def swagger(*args, **kwargs, &block)
      @@doc ||= {}
      if args.count.zero?
        # assume passing data into method call
        @@doc.merge!(SwaggerObject.new(**kwargs, &block).get)
      else
        # assume single argument is filename of existing json
        @@doc.merge!(::JSON.parse(File.read(args[0])))
      end
    end

    def desc(description)
      @@desc = description
    end

    def param(**kwargs, &block)
      @@parameters ||= []
      @@parameters << SwaggerObject.new(**kwargs, &block).get
    end

    def tags(*args)
      @@tags ||= []
      args.each{|a| @@tags << a}
    end

    def self.registered(app)
      app.get "/v2/swagger.json" do
        content_type "application/json"
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Headers'] = 'Content-Type, api-key, Authorization'
        response['Access-Control-Allow-Methods'] = 'GET, POST'
        @@doc.to_json
      end
      @@doc = {}
    end

    def self.route_added(verb, path, block)
      return if path == "/v2/swagger.json"
      return unless ["GET", "POST", "PUT", "DELETE"].include?(verb)

      @@doc["paths"] ||= {}
      @@desc ||= ""
      @@tags ||= []

      @@doc["paths"][path] = {
        verb.downcase => {
          tags: @@tags,
          description: @@desc,
          produces: [ "application/json" ],
          parameters: @@parameters,
          responses: {
            "200" => {
              description: @@desc
            }
          }
        }
      }

      @@parameters = []
      @@desc = nil
      @@tags = nil
    end
  end
end

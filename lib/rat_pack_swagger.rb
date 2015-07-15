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
      return self
    end
    def from_h(h)
      properties = definition[:properties] 
      h.each do |k,v|
        k = k.to_sym
        setter = "#{k}="
        if properties.keys.include?(k)
          # if property type references another class, instantiate it and use hash data to populate it
          if properties[k][:$ref]
            send(setter, properties[k][:$ref].new.from_h(v))
          # if property type is an ARRAY that references another class, instantiate and use hash data to populate them
          elsif properties[k][:type].to_sym == :array && properties[k][:items][:$ref]
            send(setter, v.map{|_| properties[k][:items][:$ref].new.from_h(_) })
          else
            send(setter, v)
          end
        end
      end
      return self
    end
    def to_h(recur = true)
      h = {}
      definition[:properties].keys.each do |p|
        val = send(p)
        puts val
        if recur
          if val.is_a? Array
            h[p] = val.map{|v| v.is_a?(Definition) ? v.to_h : v}
          elsif val.is_a?(Definition)
            h[p] = val.to_h
          else
            h[p] = val
          end
        else 
          h[p] = val
        end
      end
      return h
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
          raise "Invalid enum value (#{v}) for property #{k}. Valid enum values are #{enum}" unless enum.include?(v) || enum.include?(v.to_sym)
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

def transform_hash_values(obj, &block)
  if obj.is_a? Hash
    obj.each do |k,v|
      if v.is_a?(Hash) || v.is_a?(Array)
        obj[k] = transform_hash_values(v, &block)
      else
        obj[k] = yield(k,v)
      end
    end
  elsif obj.is_a? Array
    obj.each_with_index do |e,i|
      if e.is_a?(Hash) || e.is_a?(Array)
        obj[i] = transform_hash_values(e, &block)
      end
    end
  else
    raise "Argument must be a Hash or an Array."
  end
  obj
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

    def description(d)
      @@description = d
    end

    def param(**kwargs, &block)
      @@parameters ||= []
      @@parameters << SwaggerObject.new(**kwargs, &block).get
    end

    def tags(*args)
      @@tags ||= []
      args.each{|a| @@tags << a}
    end

    def summary(s)
      @@summary = s
    end

    def response(http_status_code, **kwargs, &block)
      @@responses ||= {}
      @@responses[http_status_code] = SwaggerObject.new(**kwargs, &block).get
    end

    def definitions(*constants)
      @@doc[:definitions] ||= {}
      constants.each do |constant|
        if Module === constant
          constant.constants.each do |c|
            klass = constant.const_get(c)
            if Class === klass
              @@doc[:definitions][c] = klass.definition
            end
          end
        else
          @@doc[:definitions][constant.to_s.rpartition('::').last] = constant.definition
        end
      end
    end

    def self.registered(app)
      app.get '/v2/swagger.json' do
        content_type 'application/json'
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Headers'] = 'Content-Type, api-key, Authorization'
        response['Access-Control-Allow-Methods'] = 'GET, POST'
        doc = transform_hash_values(@@doc) do |k,v|
          k.to_s == '$ref' ? "\#/definitions/#{v.to_s.rpartition('::').last}" : v
        end
        doc.to_json 
      end
      @@doc = {}
    end

    def self.route_added(verb, path, block)
      return if path == '/v2/swagger.json'
      return unless ['GET', 'POST', 'PUT', 'DELETE'].include?(verb)

      @@doc['paths'] ||= {}
      @@description ||= ''
      @@tags ||= []
      @@summary ||= ''
      @@responses ||= {}

      @@doc['paths'][path] ||= {}
      @@doc['paths'][path][verb.downcase] = {
        tags: @@tags,
        description: @@description,
        summary: @@summary,
        parameters: @@parameters,
        responses: @@responses
      }

      @@parameters = []
      @@description = nil
      @@tags = nil
      @@summary = nil
      @@responses = nil
    end
  end
end

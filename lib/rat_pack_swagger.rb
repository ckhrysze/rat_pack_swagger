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
  module Definition
    def rps_default_definition
      {
        self.class.name.to_sym => {
          type: 'object',
          required: [],
          properties: {}
        }
      }
    end

    def rps_get_definition
      @@definition ||= rps_default_definition
    end

    def method_missing(m, **kwargs, &block)
      defin = rps_get_definition
      props = defin[:properties]
      if kwargs[:$ref]
        kwargs[:$ref] = "#/definitions/#{kwargs[:$ref]}"
      end
      props[m] = SwaggerObject.new(**kwargs, &block).get
      attr_accessor m
    end

    def properties(&block)
      instance_eval &block
    end

    def required(*args)
      defin = rps_get_definition
      defin[:required].concat([*args]).uniq!
    end

    def from_h(h)
      defin = rps_get_definition
      defin[:required].each do |req|
        if !h.has_key?(req)
          raise "#{self.class.name} missing required property: '#{req}'"
        end
      end
      h.each do |k,v|
        setter = "#{k}="
        if respond_to? setter
          send(setter, v)
        end
      end
    end

    def to_h
      defin = rps_get_definition
      h = {}
      setters = methods.select{|m| m =~ /.+=$/}
      setters.each do |setter|
        getter = setter.to_s.chop
        val = send(getter)
        if defin[:required].include?(getter) && val.nil?
          raise "Cannot serialize Swagger definition - #{self.class.name} missing required property '#{getter}'"
        elsif val.respond_to?(:to_h)
          h[getter] = val.to_h
        elsif !val.nil?
          h[getter] = val
        end
      end
      return h
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

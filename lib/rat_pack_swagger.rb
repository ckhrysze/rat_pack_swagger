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

module Sinatra
  module RatPackSwagger
    def swagger(*args, **kwargs, &block)
      @@doc ||= {}
      if args.count.zero?
        # assume passing data into method call
        @@doc.merge!(SwaggerObject.new(**kwargs, &block).get)
      else
        # assume single argument is filename of existing json
        @@doc.merge!(JSON.parse(File.read(args[0])))
      end
    end

    def desc(description)
      @@desc = description
    end

    def param(**kwargs, &block)
      @@parameters ||= []
      @@parameters << SwaggerObject.new(**kwargs, &block).get
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

      @@doc["paths"][path] = {
        verb.downcase => {
          "description" => @@desc,
          "produces" => [ "application/json" ],
          "parameters" => @@parameters,
          "responses" => {
            "200" => {
              "description" => @@desc
            }
          }
        }
      }

      @@parameters = []
      @@desc = nil
    end
  end
end

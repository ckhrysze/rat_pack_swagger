require 'sinatra/base'
require 'json'

class SwaggerObject
  instance_methods.each do |m| 
    unless m =~ /^__/ || [:undef_method, :new, :method_missing, :initialize, :instance_eval, :object_id].include?(m)
      undef_method m
    end
  end

  def initialize(**kwargs, &block)
    @obj ||= {}
    @obj.merge! kwargs
    instance_eval &block
  end

  def method_missing(m, *args, &block)
    if block_given?
      @obj[m] = SwaggerObject.new(&block).to_h
    else
      @obj[m] = args[0]
    end
  end

  def to_h
    @obj
  end
end

module Sinatra
  module RatPackSwagger
    def swagger(&block) 
      @@doc.merge!(SwaggerObject.new(&block).to_h) 
    end

    def desc(description)
      @@desc = description
    end

    def param(**kwargs, &block)
      @@parameters ||= []
      @@parameters << kwargs.merge(SwaggerObject.new(&block).to_h)
    end
    
    def self.registered(app)
      app.get "/v2/swagger.json" do
        content_type "application/json"
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Headers'] = 'Content-Type, api-key, Authorization'
        response['Access-Control-Allow-Methods'] = 'GET, POST, DELETE, PUT'
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

require 'sinatra/base'

class SwaggerInfo
  def initialize(&block)
    instance_eval &block
  end

  def title(app_title)
    @title = app_title
  end

  def description(app_description)
    @description = app_description
  end

  def version(app_version)
    @version = app_version
  end

  def contact(app_contact)
    @contact = app_contact
  end

  def to_hash
    {
      title: @title,
      description: @description,
      version: @version,
      contact: {
        name: @contact[:name],
        email: @contact[:email]
      }
    }
  end
end

module Sinatra
  module RatPackSwagger
    def swagger(version)
      @@doc ||= {}
      @@doc["swagger"] = version
    end

    def info(&block)
      @@doc ||= {}
      @@doc["info"] = SwaggerInfo.new(&block).to_hash
    end

    def desc(description)
      @@desc = description
    end

    def param(opts)
      puts "in param"
      @@parameters ||= []
      puts opts
      @@parameters << opts
    end
    
    def add_swagger_route(app)
      app.get "/v2/swagger.json" do
        content_type "application/json"
        @@doc.to_json
      end
    end

    def self.route_added(verb, path, block)
      return if path == "/v2/swagger.json"
      return unless ["GET", "POST", "PUT", "DELETE"].include?(verb)

      @@doc ||= {}
      @@doc["paths"] ||= {}

      @@doc["paths"][path] = {
        verb.downcase => {
          "description" => @@desc,
          "produces" => [ "application/json" ],
          "parameters" => @@parameters.map { |p|
            {
              "name" => p[:name],
              "in" => p[:type],
              "description" => p[:desc],
              "required" => p[:required] == true,
              "type" => p[:type]
            }
          },
          "responses" => {
            "200" => {
              "description" => @@desc
            }
          }
        }
      }

      @@parameters = []
    end
  end
  
  register RatPackSwagger
end

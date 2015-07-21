require 'sinatra/base'
require 'json'
require 'json-schema'
require_relative 'swagger_object'
require_relative 'swagger_spec'
require_relative 'request_validators'

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

    def to_h
      definition
    end

    # Class declaration API
    def properties(&block)
      definition[:properties].merge!(SwaggerObject.new(&block).to_h)
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

    def from_h(h)
      properties = self.class.definition[:properties] 
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
      self.class.definition[:properties].keys.each do |p|
        val = send(p)
        if recur
          if val.is_a?(Array)
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
  end
end


module Sinatra
  module RatPackSwagger
    def _spec
      @@spec ||= ::RatPackSwagger::SwaggerSpec.new
    end
    def _validators
      @@validators ||= ::RatPackSwagger::RequestValidatorCollection.new
    end

    def swagger(*args, **kwargs, &block)
      if args.count.zero?
        # assume passing data into method call
        _spec.spec.merge!(SwaggerObject.new(**kwargs, &block).to_h)
      else
        # assume single argument is filename of existing json
        _spec.spec.merge!(::JSON.parse(File.read(args[0])))
      end
    end

    def definitions(*constants)
      _spec.add_definitions(*constants)
    end

    def description(d)
      _spec.this_route.description = d
    end

    def param(**kwargs, &block)
      _spec.this_route.parameters << SwaggerObject.new(**kwargs, &block).to_h
    end

    def tags(*args)
      _spec.this_route.tags.concat(args)
    end

    def summary(s)
      _spec.this_route.summary = s
    end

    def consumes(*args)
      _spec.this_route.consumes.concat(args)
    end

    def produces(*args)
      _spec.this_route.produces.concat(args)
    end

    def response(http_status_code, **kwargs, &block)
      _spec.this_route.responses[http_status_code] = SwaggerObject.new(**kwargs, &block).to_h
    end


    def self.registered(app)

      app.get '/v2/swagger.json' do
        content_type 'application/json'
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Headers'] = 'Content-Type, api-key, Authorization'
        response['Access-Control-Allow-Methods'] = 'GET, POST'
        errors = ::JSON::Validator.fully_validate(@@spec.swagger_schema, @@spec.api_spec, errors_as_objects: true)
        if errors.empty? then @@spec.api_spec_json else errors.to_json end 
      end

      app.before do
        @@validators ||= ::RatPackSwagger::RequestValidatorCollection.new
        vs = @@validators.get(request.path.gsub(/:(\w+)/, '{\1}'), request.request_method.downcase)
        if vs && vs[:body]
          request.body.rewind
          vs[:body].validate(request.body.read)
          request.body.rewind
        end
        # TODO: add other param types like 'query'
      end
    end

    def self.route_added(verb, path, block)
      return if path == '/v2/swagger.json'
      verb.downcase!
      path = path.gsub(/:(\w+)/, '{\1}')
      return unless ['get', 'post', 'put', 'delete'].include?(verb)
      return unless @@spec.this_route.swagger?
      @@spec.register_this_route(path, verb)

      parameters = @@spec.resolved_spec[:paths][path][verb][:parameters]
      return unless parameters

      @@validators ||= ::RatPackSwagger::RequestValidatorCollection.new
      body_param = parameters.select{|p| p[:in].to_sym == :body}.first
      if @@spec.route_consumes?(path, verb, 'application/json')
        if body_param
          @@validators.set(path, verb, :body, ::RatPackSwagger::JsonBodyValidator.new(body_param[:schema]))
        end
      # TODO: add validators for other param types like 'query'
      end
    end
  end
end

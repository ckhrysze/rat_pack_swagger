require 'json'

module RatPackSwagger
  module SwaggerType
    def to_h
      h = {}
      getters = methods.select{|m| m =~ /\w+=$/}.map{|m| m.to_s.chop}
      getters.each do |getter|
        val = send(getter)
        next if [nil, [], {}].include?(val)
        val = val.to_h if val.is_a?(SwaggerType)
        h[getter.to_sym] = val
      end
      return h
    end
  end

  class SwaggerPathItem
    include SwaggerType
    attr_accessor :get, :put, :post, :delete, :options, :head, :patch
  end

  class SwaggerOperation
    include SwaggerType
    attr_accessor :tags, :summary, :description, 
      :externalDocs, :consumes, :produces, :parameters, :responses,
      :schemes, :deprecated, :security
    def initialize
      @tags = []
      @consumes = []
      @parameters = []
      @responses = {}
      @schemes = []
      @security = []
    end
  end

  class SwaggerSpec
    attr_accessor :swagger_schema, :spec, :this_route

    def initialize
      @spec = {
        paths: {}
      }
      @spec_cache_invalid = true
      @spec_cache = {
        api_spec: nil,       # the data returned byt /v2/swagger.json
        api_spec_json: nil,  # api_spec as json string
        resolved_spec: nil,  # a hash where all json pointers are resolved 
                             # for request/response validation, because json-schema sucks at pointers
      }
      @swagger_schema = ::JSON.parse(File.read(File.join(File.dirname(__FILE__), 'swagger_json_schema.json')))
      @this_route = SwaggerOperation.new
    end

    def route_consumes?(path, verb, mime)
      route = @spec[:paths][path][verb]
      return true if route[:consumes] && route[:consumes].include?(mime)
      return true if @spec[:consumes].include?(mime)
      return false
    end

    def register_this_route(path, verb)
      verb.downcase!
      paths = @spec[:paths]
      paths[path] ||= {}
      paths[path][verb] = @this_route.to_h
      @this_route = SwaggerOperation.new
      @spec_cache_invalid = true
    end

    def add_definitions(*constants)
      @spec[:definitions] ||= {}
      constants.each do |constant|
        if constant.is_a?(Module)
          constant.constants.each do |c|
            klass = constant.const_get(c)
            if klass.is_a?(Class) && klass.ancestors.include?(Definition)
              @spec[:definitions][c] = klass.definition
            end
          end
        else
          if constant.is_a?(Class) && constant.ancestors.include?(Definition)
            @@doc[:definitions][constant.to_s.rpartition('::').last] = constant.definition
          end
        end
      end
      @spec_cache_invalid = true
    end

    def resolved_spec
      update_spec_cache if @spec_cache_invalid
      @spec_cache[:resolved_spec]
    end
    def api_spec 
      update_spec_cache if @spec_cache_invalid
      @spec_cache[:api_spec]
    end
    def api_spec_json
      update_spec_cache if @spec_cache_invalid
      @spec_cache[:api_spec_json]
    end

    private

    def update_spec_cache
      cache_resolved_spec
      cache_api_spec
      @spec_cache[:api_spec_json] = @spec_cache[:api_spec].to_json
      @spec_cache_invalid = false
    end

    def cache_resolved_spec
      resolved_spec = make_deep_copy(@spec)
      map_hash_values!(resolved_spec) do |k,v|
        new_v = v
        if v.is_a?(Hash) && v[:$ref]
          if v[:$ref].respond_to?(:to_h)
            new_v = v[:$ref].to_h
          end
        end
        new_v
      end
      @spec_cache[:resolved_spec] = resolved_spec
    end

    def cache_api_spec
      api_spec = make_deep_copy(@spec)
      map_hash_values!(api_spec) do |k,v|
        new_v = v
        if k.to_s == '$ref'
          if v.is_a?(Class)
            classname = v.to_s.rpartition('::').last
            if v.ancestors.include?(Definition)
              new_v = "#/definitions/#{classname}"
            end
            # TODO: Add other types like Parameters"
          end
        end
        new_v
      end
      @spec_cache[:api_spec] = api_spec
    end

    def make_deep_copy(arg)
      Marshal.load(Marshal.dump(arg))
    end

    def map_hash_values!(obj, &block)
      if obj.is_a? Hash
        obj.each do |k,v|
          # perform mapping first, THEN if result is hash/array, go recursive
          obj[k] = yield(k,v)
          if obj[k].is_a?(Hash) || obj[k].is_a?(Array)
            obj[k] = map_hash_values!(obj[k], &block)
          end
        end
      elsif obj.is_a? Array
        obj.each_with_index do |e,i|
          if e.is_a?(Hash) || e.is_a?(Array)
            obj[i] = map_hash_values!(e, &block)
          end
        end
      else
        raise "Argument must be a Hash or an Array."
      end
      return obj
    end

  end
end


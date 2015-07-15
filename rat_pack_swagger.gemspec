$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'rat_pack_swagger/version'

Gem::Specification.new "rat_pack_swagger", RatPackSwagger::VERSION do |s|
  s.description = "Rat Pack Swagger ties into the Sinatra DSL to build out a swagger 2.0 specification file"
  s.summary = "Extend Sinatra DSL for Swagger"
  s.require_paths = ["lib"]
  s.authors = ["Chris Hildebrand", "Mike Schreiber"]
  s.email = "ratpackswagger@ckhrysze.net"
  s.homepage = "https://github.com/ckhrysze/rat_pack_swagger"
  s.licenses = ["MIT"]
  
  s.add_dependency 'sinatra', '~> 1.4'

  s.files = Dir.glob("lib/**/*") + %w(LICENSE README.md)
  s.require_path = 'lib'
end

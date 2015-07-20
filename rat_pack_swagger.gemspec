# -*- encoding: utf-8 -*-
# stub: rat_pack_swagger 0.1.0 ruby lib

require_relative "lib/rat_pack_swagger/version"

Gem::Specification.new do |s|
  s.name = "rat_pack_swagger"
  s.version = RatPackSwagger::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Chris Hildebrand"]
  s.date = "2015-06-30"
  s.description = "Rat Pack Swagger ties into the Sinatra DSL to build out a swagger 2.0 specification file"
  s.email = "ratpackswagger@ckhrysze.net"
  s.files = ["LICENSE", "README.md", "lib/rat_pack_swagger.rb", "lib/rat_pack_swagger/version.rb"]
  s.homepage = "https://github.com/ckhrysze/rat_pack_swagger"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.8"
  s.summary = "Extend Sinatra DSL for Swagger"

  s.add_runtime_dependency("json-schema", ["~> 2.5"])

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sinatra>, ["~> 1.4"])
    else
      s.add_dependency(%q<sinatra>, ["~> 1.4"])
    end
  else
    s.add_dependency(%q<sinatra>, ["~> 1.4"])
  end
end

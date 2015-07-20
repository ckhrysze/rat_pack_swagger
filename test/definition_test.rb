require "rubygems"
require "bundler/setup"
require "minitest/autorun"
require_relative "../lib/rat_pack_swagger"

class Weapon 
  include  RatPackSwagger::Definition 
  required :power
  properties do
    power type:  :number
  end
end
class Fighter 
  include RatPackSwagger::Definition 
  required :helmet, :armor
  properties do
    helmet type: :string
    armor type: :string
    gold type: :integer, minimum: 0, maximum: 999
    weapon :$ref => Weapon
    bag type: :object, required: [:size] do
      properties do
        size type: :string, enum: ['small', 'big']
        contents type: :array, items: {type: :string}
      end
    end
  end
end


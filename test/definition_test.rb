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

describe RatPackSwagger::Definition do
  describe "Definition" do
    it "should fail on missing required property" do
      f = Fighter.new
      h = {
        helmet: 'iron helm'
      }
      f.from_h h
      assert_raises RuntimeError do
        f.validate
      end
    end

    it "should convert basic properties to hash" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate'
      }
      actual = f.from_h(h).validate.to_h
      assert_equal h, actual
    end

    it "should convert complex properties to hash" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate'
      }
      actual = f.from_h(h).validate.to_h
      assert_equal h, actual
    end

    it "should accept non-required properties" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate',
        gold: 100
      }
      actual = f.from_h(h).validate.to_h
      assert_equal h, actual
    end

    it "should allow properties of object type" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate',
        bag: {
          size: 'small',
          contents: ['potion', 'hearthstone']
        }
      }
      actual = f.from_h(h).validate.to_h
      assert_equal h, actual
    end

    it "should fail when a string gets an int" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 12345, # int
        bag: {
          size: 'small',
          contents: ['potion', 'hearthstone']
        }
      }
      assert_raises RuntimeError do
        f.from_h(h).validate
      end
    end

    it "should fail when an enum value is invalid" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate', 
        bag: {
          size: 'WHO CARES', # invalid
          contents: ['potion', 'hearthstone']
        }
      }
      assert_raises RuntimeError do
        f.from_h(h).validate
      end
    end

    it "should properly convert Class ref property to hash" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate', 
        weapon: {
          power: 9000
        }
      }
      actual = f.from_h(h).validate.to_h
      assert_equal h, actual
      assert_equal Weapon, f.weapon.class
    end

    it "should fail if integer property value less than minimum" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate', 
        gold: -1
      }
      assert_raises RuntimeError do
        f.from_h(h).validate
      end
    end

    it "should fail if integer property value greater than maximum" do
      f = Fighter.new
      h = {
        helmet: 'iron helm',
        armor: 'breast plate', 
        gold: 1000
      }
      assert_raises RuntimeError do
        f.from_h(h).validate
      end
    end
  end
end

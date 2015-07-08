require "rubygems"
require "bundler/setup"
require "minitest/autorun"
require_relative "../lib/rat_pack_swagger"

class Win < RatPackSwagger::Definition
  required :gameId, :partner, :userId
  properties do
    gameId type: :string
    partner type: :string
    userId type: :string
    gameRoundId type: :string
    payout type: :object, required: [:method] do
      properties do
        method type: :string, enum: [:percentage, :value]
        percentage type: :number, minimum: 0, maximum: 100
        value type: :object, required: [:amount, :currency] do
          properties do
            amount type: :integer
            currency type: :string
          end
        end
      end
    end
    currency type: :string
  end
end

class Fighter < RatPackSwagger::Definition
  required :helmet, :armor
  properties do
    helmet type: :string
    armor type: :string
    gold type: :integer
    weapon :$ref => Weapon
    bag type: :object, required: [:size] do
      properties do
        size type: :string, enum: [:small, :big]
        contents type: :array, items: {type: :string}
      end
    end
  end
end
class Weapon < RatPackSwagger::Definition
  required :power
  properties do
    power :type :number
  end
end

describe RatPackSwagger::Definition do
  describe "Definition" do
    it "should fail on missing required property" do
      f = Fighter.new
      data = {
        helmet: 'iron helm'
      }
      f.from_h data
      assert_raises RuntimeError do
        f.validate
      end
    end

    it "should convert basic properties to hash" do
      f = Fighter.new
      data = {
        helmet: 'iron helm',
        armor: 'breast plate'
      }
      actual = f.from_h(data).validate.to_h
      assert hash == actual
    end

    it "should convert complex properties to hash" do
      f = Fighter.new
      data = {
        helmet: 'iron helm',
        armor: 'breast plate'
      }
      actual = f.from_h(data).validate.to_h
      assert hash == actual
    end

    it "should accept non-required properties" do
      w = Win.new
      hash = {
        gameId: 'banana',
        partner: 'tomato',
        userId: 'apple',
        gameRoundId: 'shazbot'
      }
      actual = w.from_h(hash).validate.to_h
      assert hash == actual
    end

    it "should allow properties of object type" do
      w = Win.new
      hash = {
        gameId: 'banana',
        partner: 'tomato',
        userId: 'apple',
        gameRoundId: 'shazbot',
        payout: {
          method: 'value',
          value: {
            amount: 1234,
            currency: 'USD'
          }
        }
      }
      actual = w.from_h(hash).validate.to_h
      assert hash == actual
    end

    it "should fail when a string gets an int" do
      w = Win.new
      hash = {
        gameId: 'banana',
        partner: 'tomato',
        userId: 'apple',
        gameRoundId: 'shazbot',
        payout: {
          method: 'value',
          value: {
            amount: 1234,
            currency: 1 # int
          }
        }
      }
      assert_raises RuntimeError do
        w.from_h(hash).validate
      end
    end
  end
end

require 'spec_helper'

describe Eklektos::State do
  before do
    @state1 = State.new(Epoch.new("foo", 10))
    @state2 = State.new(Epoch.new("foo", 20))
    @state3 = State.new(Epoch.new("foo", 20))
    @state3.refresh
  end

  it "should compare distinct epochs properly" do
    @state1.should be < @state2
  end

  it "should compare freshness counters for equal epochs" do
    @state2.should be < @state3
  end
end

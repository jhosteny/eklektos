require 'spec_helper'

include Eklektos

describe Eklektos::View do
  before do
    @view1 = View.new(State.new(Epoch.new("foo", 10)))
    @view2 = View.new(State.new(Epoch.new("foo", 20)))
  end

  it "should compare based on the encapsulated state" do
    @view1.should be < @view2
  end

  it "should expire when the state is not updated" do
    @view1.push_state
    @view1.observe_state(@view1.state)
    @view1.expired?.should eq true
  end

  it "should unexpire when the epoch is advanced" do
    @view1.push_state
    @view1.epoch.advance
    @view1.update_expiration.expired?.should eq false
  end
end

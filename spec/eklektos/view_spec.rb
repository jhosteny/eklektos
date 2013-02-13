require 'spec_helper'

describe Eklektos::View do
  before do
    @view1 = Eklektos::View.new(Eklektos::State.new(Eklektos::Epoch.new("foo", 10)))
    @view2 = Eklektos::View.new(Eklektos::State.new(Eklektos::Epoch.new("foo", 20)))
  end

  it "should compare based on the encapsulated state" do
    @view1.should be < @view2
  end

  it "should expire" do
    @view1.expire!
    @view1.expired?.should be true
  end

  it "should unexpire" do
    @view1.unexpire!
    @view1.expired?.should be false
  end
end
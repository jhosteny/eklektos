require 'spec_helper'

describe Eklektos::Epoch do
  before do
    @epoch1 = Eklektos::Epoch.new("foo", 10)
    @epoch2 = Eklektos::Epoch.new("foo", 20)
    @epoch3 = Eklektos::Epoch.new("bar", 20)
  end

  it "should compare distinct serials properly" do
    @epoch1.should be < @epoch2
  end

  it "should compare ids for equal serials" do
    @epoch3.should be < @epoch2
  end
end
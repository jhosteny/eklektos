require 'spec_helper'

describe Eklektos::Epoch do
  before do
    @epoch1 = Epoch.new("foo", 10)
    @epoch2 = Epoch.new("foo", 20)
    @epoch3 = Epoch.new("bar", 20)
    @epoch4 = Epoch.new("bar", 20)
  end

  it "should compare distinct serials properly" do
    @epoch1.should be < @epoch2
  end

  it "should compare ids for equal serials" do
    @epoch3.should be < @epoch2
  end

  it "should find equal epochs" do
    @epoch4.should eq @epoch3
  end

  it "should advance epochs properly" do
    @epoch4.advance
    @epoch4.should be > @epoch3
  end
end

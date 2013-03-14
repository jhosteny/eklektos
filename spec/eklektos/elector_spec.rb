require 'spec_helper'
require 'timeout'

describe Eklektos::Elector do
  let(:me) { DCell.me.find(:elector) }

  before :each do
    me.refreshed
    me.cohorts.values.each { |cohort| cohort.actor.refreshed unless cohort.id == DCell.id }
  end

  after :each do
    sleep 0.1
  end

  it "should refresh all cohorts properly" do
    me.wrapped_object.should_receive(:refreshed).once
    me.send_refresh
  end

  it "should not refresh without a quorum of cohorts" do
    me.wrapped_object.should_receive(:with_peers).with(false).once.and_return(nil)
    me.wrapped_object.should_not_receive(:refreshed)
    me.send_refresh
  end

  it "should collect from all cohorts properly" do
    views = me.views
    me.wrapped_object.should_receive(:collected).once do |arg|
      arg.each do |id, state|
        views[id].state.should be < state
      end
    end
    me.send_collect
  end

=begin
  it "should receive a timeout when there is no quorum" do
    me.wrapped_object.should_receive(:with_peers).with(false).once.and_return(nil)
    me.wrapped_object.should_receive(:rtt_timeout).exactly(1).times
    me.send_refresh
    # Ugly!
    sleep Eklektos::Elector::RTT_TIMEOUT + 0.1
  end
=end
end

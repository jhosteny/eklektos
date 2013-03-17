require 'spec_helper'
require 'timeout'

describe Eklektos::Elector do
  let(:me) { DCell.me.find(:elector) }

  before :each do
    me.cohorts.values.each { |cohort| cohort.actor.refreshed } #unless cohort.id == DCell.id }
  end

  it "should not refresh without a quorum of cohorts" do
    me.wrapped_object.stub(:leading?).and_return(true, false)
    me.wrapped_object.stub(:exiting?).and_return(true)
    me.wrapped_object.should_receive(:with_peers).once.and_return(nil)
    me.wrapped_object.should_not_receive(:refreshed)
    me.wrapped_object.should_receive(:refresh_timeout)
    me.refresh_process
  end

  it "should refresh all cohorts properly" do
    me.wrapped_object.stub(:leading?).and_return(true, false)
    me.wrapped_object.stub(:exiting?).and_return(true)
    me.wrapped_object.should_receive(:refreshed).once
    me.refresh_process
  end

  it "should collect from all cohorts properly" do
    me.wrapped_object.should_receive(:collected).twice
    me.wrapped_object.stub(:exiting?).and_return(true)
    me.collect_process(true)
  end

=begin
  it "should not refresh without a quorum of cohorts" do
    me.wrapped_object.should_receive(:with_peers).once.and_return(nil)
    me.wrapped_object.should_not_receive(:refreshed)
    me.send_refresh
  end

  it "should collect from all cohorts properly" do
    views = me.views
    me.wrapped_object.should_receive(:collected).once do |max_registries, collect_start_time|
      max_registries.each do |id, state|
        views[id].state.should be < state
      end
    end
    me.send_collect
  end
=end

=begin
  it "should receive a timeout when there is no quorum" do
    me.wrapped_object.should_receive(:with_peers).once.and_return(nil)
    me.wrapped_object.should_receive(:rtt_timeout).exactly(1).times
    me.send_refresh
    # Ugly!
    sleep Eklektos::Elector::RTT_TIMEOUT + 0.1
  end
=end
end

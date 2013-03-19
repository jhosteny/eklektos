require 'spec_helper'
require 'timeout'

describe Eklektos::Elector do
  let(:me) { DCell.me.find(:elector) }

  before :each do
    me.cohorts.values.each { |cohort| cohort.actor.transition :shutdown }
    me.cohorts.values.each { |cohort| cohort.actor.refreshed }
  end

  it "should not refresh without a quorum of cohorts" do
    me.wrapped_object.should_receive(:with_peers).once.and_return(nil)
    me.wrapped_object.should_not_receive(:refreshed)
    me.wrapped_object.should_receive(:transition).with(:advance)
    me.refresh_process
  end

  it "should refresh all cohorts properly" do
    me.wrapped_object.should_receive(:refreshed).once
    me.refresh_process
  end

  it "should collect from all cohorts properly" do
    me.wrapped_object.should_receive(:collected).once
    me.collect_process
  end

  it "should advance the epoch properly" do
    me.wrapped_object.should_receive(:got_max_epoch).once
    me.epoch_process
  end

=begin
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
end

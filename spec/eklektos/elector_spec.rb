require 'spec_helper'
require 'timeout'

describe Eklektos::Elector do
  let(:me) { DCell.me.find(:elector) }

  before :all do
    Eklektos::Elector.class_eval { attr_reader :refresh_seq }
  end

  before :each do
    me.send(:registered).refresh
  end

  it "should refresh all cohorts properly" do
    expect { me.send_refresh }.to change { me.refresh_seq }.by(2)
  end

  it "should not refresh without a quorum of cohorts" do
    me.wrapped_object.should_receive(:with_peers).with(false).once.and_return(nil)
    expect { me.send_refresh }.to change { me.refresh_seq }.by(1)
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

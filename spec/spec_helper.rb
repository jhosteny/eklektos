require 'rubygems'
require 'bundler'
Bundler.setup

require 'eklektos'
Dir['./spec/support/*.rb'].map { |f| require f }

class TestNode
  include TestNodeHelper
end

RSpec.configure do |config|
  config.before(:suite) do
    DCell.setup
    DCell.run!

    $node_1 = TestNode.new
    $node_1.start
    $node_1.wait_until_ready

    $node_2 = TestNode.new
    $node_2.start
    $node_2.wait_until_ready

    $node_3 = TestNode.new
    $node_3.start
    $node_3.wait_until_ready
  end

  config.after(:suite) do
    $node_1.stop
    $node_2.stop
    $node_3.stop
  end
end

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
    count = 3
    $nodes = (count - 1).times.collect do |i|
      node = TestNode.new
      node.start(i, count)
      node.wait_until_ready
      node
    end
    port = TestNode.next_port
    puts "Starting in memory cell on port #{port}"
    DCell.start :id => "node_#{count - 1}", :addr => "tcp://127.0.0.1:#{port}"
    Elector.supervise_as :elector, *count.times.collect { |i| "node_#{i}" }
  end

  config.after(:suite) do
    $nodes.each { |node| node.stop }
  end
end

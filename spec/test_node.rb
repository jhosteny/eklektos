# The eklektos specs start a completely separate Ruby VM running this code
# for complete integration testing using DCell
require 'rubygems'
require 'bundler'
Bundler.setup

require 'dcell'
require 'eklektos'

if __FILE__ == $0
  DCell.start :id => "node_#{ARGV[0]}", :addr => "tcp://127.0.0.1:#{ARGV[1]}"
  Eklektos::Elector.supervise_as :elector, *ARGV[2].to_i.times.collect { |i| "node_#{i}" }
  sleep
end

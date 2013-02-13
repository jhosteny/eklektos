# The eklektos specs start a completely separate Ruby VM running this code
# for complete integration testing using DCell
require 'rubygems'
require 'bundler'
Bundler.setup

require 'dcell'

class TestElector
  include Celluloid

  def crash
    raise "the spec purposely crashed me :("
  end
end

if __FILE__ == $0
  DCell.start :id => "#{ARGV[0]}", :addr => "tcp://127.0.0.1:#{ARGV[1]}"
  TestElector.supervise_as :test_elector
  sleep
end

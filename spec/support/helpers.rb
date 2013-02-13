require 'rubygems'

module TestNodeHelper
  PORT = 38728
  NODE = 0

  class << self
    attr_reader :next_port
    attr_reader :next_node

    def included(klass)
      klass.send :extend,  ClassMethods
      klass.send :include, InstanceMethods
    end
  end

  module ClassMethods
    def next_port
      @next_port ||= PORT
      @next_port += 1
      @next_port
    end

    def next_node
      @next_node ||= NODE
      @next_node += 1
      @next_node
    end
  end

  module InstanceMethods
    def start
      @port = self.class.next_port
      @node = self.class.next_node
      @pid = Process.spawn(Gem.ruby, File.expand_path("../../test_node.rb", __FILE__), "node_#{@node}", @port.to_s)
    end

    def wait_until_ready
      STDERR.print "Waiting for test node at port #{@port} to start up..."

      socket = nil
      30.times do
        begin
          socket = TCPSocket.open("127.0.0.1", @port)
          break if socket
        rescue Errno::ECONNREFUSED
          STDERR.print "."
          sleep 1
        end
      end

      if socket
        STDERR.puts " done!"
        socket.close
      else
        STDERR.puts " FAILED!"
        raise "couldn't connect to test node at port #{@port}!"
      end
    end

    def stop
      Process.kill 9, @pid
    rescue Errno::ESRCH
    ensure
      Process.wait @pid rescue nil
    end
  end
end
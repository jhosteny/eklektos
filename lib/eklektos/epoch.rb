module Eklektos
  class Epoch
    include Comparable

    # The distinguishing id for the epoch, canonically the DCell node id
    attr_reader :id

    # The monotonically increasing serial number of the epoch
    attr_reader :serial

    # The start time for the epoch
    attr_reader :start

    # Creates a new epoch
    # @param id [String] The node id. This can be any object which uniquely identifies the DCell node and implements
    # Comparable, but we'll use the DCell node id (a String)
    # @param serial [Fixnum] The epoch serial number
    def initialize(id, serial=0)
      @id, @serial, @start = id, serial, Time.now
    end

    # Creates a new elector epoch as a copy
    # @param other [Epoch] The epoch to copy
    def initialize_copy(other)
      @id, @serial = other.id, other.serial
    end

    # Provides lexicographic comparison of two epochs. Precedence is given to the serial number, followed by the id.
    # @param other [Epoch] The epoch to compare self to
    def <=>(other)
      if @serial != other.serial
        @serial <=> other.serial
      else
        @id <=> other.id
      end
    end

    def advance(other=nil)
      if other
        @serial = other.serial + 1
      else
        @serial += 1
      end
      @start = Time.now
      self
    end

    # Provides a string representation of epoch for debugging
    # @return [String] The epoch as a string
    def to_s
      "<s: #{@serial}, id: #{@id}, start: #{@start}>"
    end
  end
end

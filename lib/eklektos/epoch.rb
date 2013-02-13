module Eklektos
  class Epoch
    include Comparable

    # The distinguishing id for the epoch, canonically the DCell node id
    attr_reader :id

    # The monotonically increasing serial number of the epoch
    attr_reader :serial

    # Creates a new epoch
    # @param id [String] The node id. This can be any object which uniquely identifies the DCell node and implements
    # Comparable.
    # @param serial [Fixnum] The epoch serial number
    def initialize(id, serial)
      @id, @serial = id, serial
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

    # Provides a string representation of epoch for debugging
    # @return [String] The epoch as a string
    def to_s
      "<s: #{@serial}, id: #{@id}>"
    end
  end
end
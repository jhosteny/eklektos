module Eklektos
  class State
    include Comparable

    # The epoch associated with the state
    attr_reader :epoch

    # The freshness counter
    attr_reader :freshness

    # Creates a new elector state
    # @param epoch [Epoch] The epoch of the state
    # @param fresh [Fixnum] The freshness of the state
    def initialize(epoch, freshness=0)
      @epoch     = epoch
      @freshness = freshness
    end

    # Creates a new elector state as a copy
    # @param other [State] The state to copy
    def initialize_copy(other)
      @epoch, @freshness = other.epoch.dup, other.freshness
    end

    # Provides lexicographic comparison of two states. Precedence is given to the epoch,
    # followed by the freshness counter.
    # @param other [State] The state to compare self to
    def <=>(other)
      if epoch != other.epoch
        epoch <=> other.epoch
      else
        @freshness <=> other.freshness
      end
    end

    def refresh
      @freshness += 1
    end

    # Provides a string representation of state for debugging
    # @return [String] The state as a string
    def to_s
      "<e: #{epoch.to_s}, f: #{@freshness}>"
    end
  end
end

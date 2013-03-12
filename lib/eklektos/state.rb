module Eklektos
  class State
    include Comparable

    # The epoch associated with the state
    attr_reader :epoch

    # The freshness counter
    attr_reader :fresh

    # Creates a new elector state
    # @param epoch [Epoch] The epoch of the state
    # @param fresh [Fixnum] The freshness of the state
    def initialize(epoch, fresh=0)
      @epoch = epoch
      @fresh = fresh
    end

    # Creates a new elector state as a copy
    # @param other [State] The state to copy
    def initialize_copy(other)
      @epoch, @fresh = other.epoch.dup, other.fresh
    end

    # Provides lexicographic comparison of two states. Precedence is given to the epoch,
    # followed by the freshness counter.
    # @param other [State] The state to compare self to
    def <=>(other)
      if epoch != other.epoch
        epoch <=> other.epoch
      else
        @fresh <=> other.fresh
      end
    end

    # Provides staleness comparison of two states. A stale state expires a view.
    # @param other [State] The state to compare self to
    # @return [boolean] true if the state is stale compared to other
    def stale?(other)
      stale = self <= other
      stale = false if epoch > other.epoch
      stale
    end

    def refresh
      @fresh += 1
      self
    end

    def update(other)
      if self < other
        self.epoch = other.epoch
        self.fresh = other.fresh
        true
      else
        false
      end
    end

    # Provides a string representation of state for debugging
    # @return [String] The state as a string
    def to_s
      "<e: #{epoch.to_s}, f: #{@fresh}>"
    end
  end
end

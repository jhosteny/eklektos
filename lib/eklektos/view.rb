module Eklektos
  class View
    include Comparable
    extend Forwardable

    # The current state associated with the view
    attr_reader :state

    # The old state associated with the view
    attr_reader :old_state

    # Flag indicating whether or not the view is expired
    attr_reader :expired

    def_delegators :@state, :epoch, :epoch=

    # Constructs a new view with the given state and expiration
    # @param state [State] The state to be associated with the view
    def initialize(state)
      @state   = state
      @expired = true
    end

    # Creates a new elector view as a copy
    # @param other [View] The view to copy
    def initialize_copy(other)
      @state, @old_state, @expired = other.state, other.old_state, other.expired
    end

    # Provides lexicographic comparison of two views using the encapsulated state
    # @param other [View] The view to compare self to
    def <=>(other)
      state <=> other.state
    end

    def observe_state(other_state)
      if state < other_state
        @state = other_state.dup
      end
      self
    end

    def push_state
      @old_state = state.dup
      self
    end
    
    def update_expiration
      if state <= old_state
        @expired = true
      elsif state.epoch > old_state.epoch
        @expired = false
      end
      self
    end

    # Get the state of the view
    # @return Whether the view is expired
    def expired?
      expired
    end
  end
end

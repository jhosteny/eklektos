module Eklektos
  class View
    include Comparable

    # The state associated with the view
    attr_reader :state

    # Flag indicating whether or not the view is expired
    attr_reader :expired

    # Constructs a new view in the expired state
    # @param state [State] The state to be associated with the view
    def initialize(state)
      @state   = state
      @expired = true
    end

    # Creates a new elector state as a copy
    # @param other [View] The view to copy
    def initialize_copy(other)
      @state, @expired = other.state.dup, other.expired
    end

    # Provides lexicographic comparison of two views using the encapsulated state
    # @param other [View] The view to compare self to
    def <=>(other)
      @state <=> other.state
    end

    # Get the state of the view
    # @return Whether the view is expired
    def expired?
      @expired
    end

    # Expire the view
    def expire!
      @expired = true
    end

    # Unexpire the view
    def unexpire!
      @expired = false
    end
  end
end
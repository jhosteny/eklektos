module Eklektos
  class Elector
    include Celluloid
    extend Forwardable

    # Failure detection and leader election
    REFRESH_TIMEOUT = 12
    RTT_TIMEOUT     = 2
    READ_TIMEOUT    = REFRESH_TIMEOUT + RTT_TIMEOUT

    # The set of all cohorts, including ourself
    attr_reader :cohorts

    # The cohort registry, as broadcast to us by our peers
    attr_reader :registry

    # The cohort views, as we have read them from our peers
    attr_reader :views

    def_delegators :"@registry[DCell.id]", :epoch, :epoch=
    def_delegators :"@views[DCell.id]", :view, :view=
    def_delegator :DCell, :id

    def initialize(*cohort_ids)
      cohort_ids.push DCell.id unless cohort_ids.include? DCell.id
      @cohorts  = {}
      @registry = {}
      @views    = {}
      cohort_ids.each do |id|
        @cohorts [id] = Cohort.new(id)
        @registry[id] = State.new(Epoch.new(id))
        @views   [id] = nil
      end
      @leading     = false
      @collecting  = false
      @refresh_seq = 0
    end

    #
    # Refresh
    #
    def refresh_timeout
      unless leading? || collecting?
        DCell::Logger.info "Stopping refresh at follower #{id}"
        return
      end
      @refresh_timer = after(REFRESH_TIMEOUT) { refresh_timeout }
      send_refresh
    end

    def send_refresh
      DCell::Logger.debug "Start refresh at #{id}"
      @refresh_acks = 0
      @refresh_seq += 1
      @rtt_timer    = after(RTT_TIMEOUT) { rtt_timeout }
      
      # We only send this to our peers, not ourself, since the check for
      # refreshing the registry is that the value 'r' sent from a process
      # 'p' to a process 'q' is that the local registry value for 'p' at
      # 'q' must be strictly less than the sent value to be updated. We
      # could do a conditional check on the sender when comparing, but I
      # think this is a little clearer when comparing the code to the paper.
      with_peers(false) { |proxy| proxy.refresh(id, @refresh_seq, registered) }
      
      # Now pretend we refreshed.
      refresh_ack(@refresh_seq)
    end

    def refresh(from, seq, from_state)
      respond_to(from) do |proxy|
        if registry[from] < from_state
          registry[from] = from_state
          proxy.refresh_ack(seq)
        end
      end
    end

    def refresh_ack(seq)
      return if seq != @refresh_seq
      @refresh_acks += 1
      if @refresh_acks >= quorum
        @refresh_seq += 1
        @rtt_timer.cancel if @rtt_timer
        @rtt_timer = nil
        registered.refresh
      end
    end

    private

    def leading?;    @leading    end
    def collecting?; @collecting end

    def registered
      registry[DCell.id]
    end

    def registered=(state)
      registry[DCell.id] = state
    end

    def quorum
      @cohorts.size / 2 + 1
    end

    def with_peers(include_self=true, &block)
      cohorts.values.each { |cohort| block.call(cohort.actor.async) if include_self || cohort.id != DCell.id }
    end

    def respond_to(from, &block)
      cohort = cohorts[from]
      block.call(cohort.actor) if cohort
    end
  end
end

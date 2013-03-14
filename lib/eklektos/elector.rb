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

    def_delegators :"@views[DCell.id]", :view, :view=
    def_delegator :DCell, :id, :me

    def initialize(*cohort_ids)
      cohort_ids.push me unless cohort_ids.include? me
      @cohorts  = {}
      @registry = {}
      @views    = {}
      cohort_ids.each do |id|
        @cohorts [id] = Cohort.new(id)
        @registry[id] = State.new(Epoch.new(id))
        @views   [id] = View.new(State.new(Epoch.new(id)))
      end
      @leading     = false
      @collects    = 0
      @refresh_seq = 0
      @collect_seq = 0
    end

    #
    # Refresh
    #
    def refresh_timeout
      unless leading? || collecting?
        DCell::Logger.info "Stopping refresh at follower #{me}"
        return
      end
      @refresh_timer = after(REFRESH_TIMEOUT) { refresh_timeout }
      send_refresh
    end

    def send_refresh
      DCell::Logger.debug "Start refresh at #{me}"
      @refresh_acks = 0
      @refresh_seq += 1
      @rtt_timer    = after(RTT_TIMEOUT) { rtt_timeout }
      
      # We only send this to our peers, not ourself, since the check for
      # refreshing the registry is that the value 'r' sent from a process
      # 'p' to a process 'q' is that the local registry value for 'p' at
      # 'q' must be strictly less than the sent value to be updated. We
      # could do a conditional check on the sender when comparing, but I
      # think this is a little clearer when comparing the code to the paper.
      with_peers(false) { |proxy| proxy.refresh(me, @refresh_seq, registered) }
      
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
        refreshed
      end
    end

    def refreshed
      registered.refresh
    end

    #
    # Collect
    #
    def start_collect
      collecting = @collects > 0
      @collects += 2
      unless collecting
        @refresh_timer.cancel if @refresh_timer
        @refresh_timer = nil

        # Revive our own epoch number first. This is something else
        # that's not very clear in the paper. It states that the
        # collect is run when the leader refresh isn't observed
        # locally, or we observe a lower epoch in a refresh from
        # another peer. The collect is then run twice to determine
        # who the new leader is. Since it may be us, it is imperative
        # to refresh ourself so that our local view is not expired
        # by a non-increasing freshness counter in the collect. The
        # read should happen after the full time has been allotted
        # for the refresh to complete.
        refresh_timeout

        delayed_collect
      end
    end

    def delayed_collect
      @collect_timer = after(RTT_TIMEOUT) { send_collect }
    end

    def send_collect
      @last_collect_start_time = Time.now
      @collect_acks = 0
      @collect_seq += 1
      @collected_max = {}

      views.each { |_, view| view.push_state }
      with_peers(false) { |proxy| proxy.collect(me, @collect_seq) }
    end

    def collect(from, seq)
      respond_to(from) do |proxy|
        DCell::Logger.debug "collect at #{me}, state: #{registered}"
        proxy.collect_ack(seq, registry)
      end
    end

    def collect_ack(seq, registry)
      return if @collect_seq != seq
      registry.each do |id, state|
        @collected_max[id] ||= registry[id]
        @collected_max[id] = registry[id] if @collected_max[id] < registry[id]
      end
      @collect_acks += 1
      if @collect_acks >= quorum
        @collect_seq += 1
        collected(@collected_max, @last_collect_start_timer)
      end
    end

    def collected(max_registries, collect_start_time)
      max_registries.each { |id, state| views[id].update(state) }
      views.each do |id, view|
        expired = view.expired?
        view.update_expiration
        DCell::Logger.debug "Cohort #{id} #{view.expired? ? 'expired' : 'unexpired'}" if view.expired? != expired
      end
      leader_id, leader_view = views.reject { |_, view| view.expired? }.min_by { |_, view| view.epoch }
      set_leader(leader_id, leader_view, collect_start_time) if leader_id
      delayed_collect
    end

    private

    def leader_elapsed?(collect_start_time)
      collect_start_time - registered.epoch.start >= 2 * REFRESH_TIMEOUT + 3 * RTT_TIMEOUT
    end

    def set_leader(new_leader, view, collect_start_time)
      DCell::Logger.info "Discovered leader #{new_leader}, epoch #{view.epoch} at #{me}" if @leader != new_leader
      @leader = new_leader
      if leading?
        if @leader != me
          DCell::Logger.info "#{me} lost leadership"
          @leading = false
        end
      else
        if view.epoch == registry[me].epoch && leader_elapsed?(collect_start_time)
          DCell::Logger.info "#{me} becoming leader"
          @leading = true
        end
      end
    end

    def leading?;    @leading      end
    def collecting?; @collects > 0 end

    def registered
      registry[me]
    end

    private
    def registered=(state)
      registry[me] = state
    end

    def quorum
      @cohorts.size / 2 + 1
    end

    def with_peers(include_self=true, &block)
      cohorts.values.each { |cohort| block.call(cohort.actor.async) if include_self || cohort.id != me }
    end

    def respond_to(from, &block)
      cohort = cohorts[from]
      block.call(cohort.actor) if cohort
    end
  end
end

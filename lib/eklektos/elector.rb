module Eklektos
  class Elector
    include Celluloid
    include Celluloid::FSM
    extend Forwardable

    # Failure detection and leader election
    REFRESH_TIMEOUT = 12
    RTT_TIMEOUT     = 2
    READ_TIMEOUT    = REFRESH_TIMEOUT + RTT_TIMEOUT
    LEADER_TIMEOUT  = 2 * REFRESH_TIMEOUT + 3 * RTT_TIMEOUT

    # The set of all cohorts, including ourself
    attr_reader :cohorts

    # The cohort registry, as broadcast to us by our peers
    attr_reader :registry

    # The cohort views, as we have read them from our peers
    attr_reader :views

    def_delegator :DCell, :id, :me

    def initialize(*cohort_ids)
      super()
      cohort_ids.push me unless cohort_ids.include? me
      @cohorts  = {}
      @registry = {}
      @views    = {}
      cohort_ids.each do |id|
        @cohorts [id] = Cohort.new(id)
        @registry[id] = State.new(Epoch.new(id))
        @views   [id] = View.new(State.new(Epoch.new(id)))
      end
    end

    # FSM
    default_state :start
    state :start do
      epoch_process
      transition :collecting
    end

    state :collecting do
      DCell::Logger.debug "Collecting"
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
      refresh_once

      # Now refresh for the duration of the collect
      timer = every(REFRESH_TIMEOUT) { refresh_once }

      collect_process

      timer.cancel

      # This appears to be important. TODO: figure out why
      # we crash otherwise
      nil
    end

    # We need separate states since we can't transition back
    # into the same state. It seems like this has changed in
    # Celluloid, since the DCell heartbeat mechanism appears
    # to assume that you can. TODO: investigate.
    state :leading do
      transition :reaffirm_leading, :delay => REFRESH_TIMEOUT
      refresh_process
    end

    state :reaffirm_leading do
      DCell::Logger.debug "Reaffirming leadership"
      transition :leading
    end

    state :advance do
      epoch_process
      transition :leading
    end

    state :following do
      # Unless the heartbeat is received, look for a new leader
      transition :collecting, :delay => 2 * REFRESH_TIMEOUT
    end

    state :reaffirm_following do
      DCell::Logger.debug "Reaffirming following"
      transition :following
    end

    state :shutdown
    
    #
    # Refresh
    #
    def refresh_once
      loop do
        break if refresh_internal do
          epoch_process
        end
      end
    end

    def refresh_process
      refresh_internal do
        transition :advance
      end
    end

    def refreshed
      registered.refresh
      DCell::Logger.debug "Refreshed #{registered}"
    end

    def refresh(from, seq, state)
      respond_to(from) do |proxy|
        if registry[from] < state
          registry[from] = state
          proxy.refresh_ack(seq)
        end

        if @leader
          # Start a collect if we detect a stale epoch.
          if views[@leader].epoch > registry[from].epoch
            DCell::Logger.info "Saw epoch #{registry[from].epoch} from #{from} " +
              "less than leader #{@leader} epoch #{views[@leader].epoch}"
            transition :collecting
          elsif from == @leader
            # Keep the watchdog happy.
            transition :reaffirm_following
          end
        end
      end
    end

    def refresh_ack(seq)
      signal :refreshed, seq
    end

    #
    # Epoch
    #
    def epoch_process
      loop do
        set_leadership(false)
        view.expire!
        max = registered.epoch

        @epoch_sequence ||= 0
        @epoch_sequence  += 1

        # We only send this to our peers, not ourself, since we already
        # have set the max epoch value to our own epoch.
        with_peers { |proxy| proxy.get_max_epoch(me, @epoch_sequence) }
      
        # Now pretend we called ourself.
        async.get_max_epoch_ack(@epoch_sequence, max)

        timeout = quorum_wait(:advanced, @epoch_sequence, RTT_TIMEOUT) do |epoch|
          max = epoch if epoch > max
        end

        if timeout
          DCell::Logger.debug "Advance epoch timeout"
        else
          got_max_epoch(max)
          break
        end
      end
    end

    def got_max_epoch(max_epoch)
      registered.epoch.advance(max_epoch)
      DCell::Logger.debug "Setting epoch to #{registered.epoch}"
    end

    def get_max_epoch(from, seq)
      respond_to(from) do |proxy|
        proxy.get_max_epoch_ack(seq, registry.values.max_by(&:epoch).epoch)
      end
    end

    def get_max_epoch_ack(seq, max_epoch)
      signal :advanced, [seq, max_epoch]
    end

    #
    # Collect
    #
    def collect_process
      loop do
        last_read_start_time = Time.now
        
        @collect_sequence ||= 0
        @collect_sequence  += 1

        # Save the old views
        views.each { |_, view| view.push_state }

        # Send to ourself, too. We have the registry locally, but
        # this simplifies collecting the result a bit.
        with_peers(true) { |proxy| proxy.collect(me, @collect_sequence) }

        timeout = quorum_wait(:collected, @collect_sequence, RTT_TIMEOUT) do |remote_registry|
          remote_registry.each { |id, state| views[id].update(state) }
        end

        if timeout
          DCell::Logger.debug "Collect timeout"
        else
          collected(last_read_start_time)
          break if state != :collecting
          sleep(READ_TIMEOUT)
        end
      end
    end

    def collected(last_read_start_time)
      views.each do |id, view|
        view.update_expiration do |expired|
          DCell::Logger.debug "View #{id} #{expired ? 'expired' : 'unexpired'}"
        end
      end
      set_leader(find_leader, last_read_start_time)
    end

    def collect(from, seq)
      respond_to(from) do |proxy|
        proxy.collect_ack(seq, registry)
      end
    end

    def collect_ack(seq, remote_registry)
      signal :collected, [seq, remote_registry]
    end

    private

    def refresh_internal(&block)
      @refresh_sequence ||= 0
      @refresh_sequence  += 1

      # We only send this to our peers, not ourself, since the check for
      # refreshing the registry is that the value 'r' sent from a process
      # 'p' to a process 'q' is that the local registry value for 'p' at
      # 'q' must be strictly less than the sent value to be updated. We
      # could do a conditional check on the sender when comparing, but I
      # think this is a little clearer when comparing the code to the paper.
      with_peers { |proxy| proxy.refresh(me, @refresh_sequence, registered) }
      
      # Now pretend we refreshed.
      async.refresh_ack(@refresh_sequence)

      if quorum_wait(:refreshed, @refresh_sequence, RTT_TIMEOUT)
        DCell::Logger.debug "Refresh timeout"
        block.call if block
        false
      else
        refreshed
        true
      end
    end

    def quorum_wait(symbol, sequence, timeout=nil, &block)
      rtt = after(timeout) { signal(symbol, nil) } if timeout
      acks = 0
      while acks < quorum
        seq, *rest = wait(symbol)
        if seq
          if seq == sequence
            acks += 1
            block.call(*rest) if block
          end
        else
          rtt.cancel if rtt
          return true
        end
      end
      rtt.cancel if rtt
      false
    end

    def find_leader
      leader_id, _ = views.reject { |_, view| view.expired? }.min_by { |_, view| view.epoch }
      leader_id
    end

    def set_leader(leader_id, collect_start_time)
      return if leader_id.nil?
      DCell::Logger.info "Discovered leader #{leader_id}, epoch #{views[leader_id].epoch} at #{me}" if @leader != leader_id
      @leader = leader_id
      if leading?
        if @leader != me
          set_leadership(false)
        end
      else
         if views[leader_id].epoch == registry[me].epoch &&
            (collect_start_time - registered.epoch.start) >= LEADER_TIMEOUT
          set_leadership(true)
        end
      end
    end

    def set_leadership(leading)
      if leading? != leading
        if leading
          DCell::Logger.info "#{me} becoming leader #{@leader}"
          transition :leading
        else
          DCell::Logger.info "#{me} lost leadership"
          transition :following
        end
      end
    end

    def leading?; state == :leading end

    def registered
      registry[me]
    end

    def registered=(state)
      registry[me] = state
    end

    def view
      views[me]
    end

    def quorum
      @cohorts.size / 2 + 1
    end

    def with_peers(include_self=false, &block)
      cohorts.values.each { |cohort| block.call(cohort.actor.async) if include_self || cohort.id != me }
    end

    def respond_to(from, &block)
      cohort = cohorts[from]
      block.call(cohort.actor) if cohort
    end
  end
end

module Eklektos
  class Elector
    include Celluloid
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
      cohort_ids.push me unless cohort_ids.include? me
      @cohorts  = {}
      @registry = {}
      @views    = {}
      cohort_ids.each do |id|
        @cohorts [id] = Cohort.new(id)
        @registry[id] = State.new(Epoch.new(id))
        @views   [id] = View.new(State.new(Epoch.new(id)))
      end
      @leading    = false
      @exiting    = false
      @collecting = false
      @ticks      = 0
    end

    def interval(secs, &block)
      start = Time.now
      block.call
      rest = secs - (Time.now - start)
      sleep(rest) if rest > 0
    end

    def pause(process)
      DCell::Logger.info "Stopping #{process}"
      unless exiting?
        wait(process)
        DCell::Logger.info "Starting #{process}" unless exiting?
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

    #
    # Refresh
    #
    def refresh_process
      sequence = 0
      loop do
        unless leading? || collecting?
          pause(:refresh)
          return if exiting?
        end

        sequence += 1

        # We only send this to our peers, not ourself, since the check for
        # refreshing the registry is that the value 'r' sent from a process
        # 'p' to a process 'q' is that the local registry value for 'p' at
        # 'q' must be strictly less than the sent value to be updated. We
        # could do a conditional check on the sender when comparing, but I
        # think this is a little clearer when comparing the code to the paper.
        with_peers { |proxy| proxy.refresh(me, sequence, registered) }
      
        # Now pretend we refreshed.
        async.refresh_ack(sequence)

        interval(REFRESH_TIMEOUT) do
          if quorum_wait(:refreshed, sequence, RTT_TIMEOUT)
            refresh_timeout
            break
          end
          refreshed
        end
      end
    end

    def refreshed
      registered.refresh
    end

    def refresh_timeout
      DCell::Logger.debug "Refresh timeout"
      set_leadership(false)
      view.expire!
      epoch_timeout
    end

    def refresh(from, seq, state)
      respond_to(from) do |proxy|
        @ticks += 1 if from == @leader
        if registry[from] < state
          registry[from] = state
          proxy.refresh_ack(seq)
        end
      end
    end

    def refresh_ack(seq)
      signal :refreshed, seq
    end

    #
    # Collect
    #
    def collect_process(immediate=false)
      sequence = 0
      loop do
        unless immediate
          @collecting = false
          pause(:collect)
          return if exiting?
          @collecting = true
        end
        immediate = false

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
        #
        # We sleep twice the RTT_TIMEOUT to allow any outstanding
        # refresh to complete, followed by the refresh to revive
        # our local view.
        signal :refresh
        sleep(2 * RTT_TIMEOUT)

        times = 2
        while times > 0
          puts "Collecting time #{times}"
          last_read_start_time = Time.now
          sequence += 1

          # Save the old views
          views.each { |_, view| view.push_state }

          # Send to ourself, too. We have the registry locally, but
          # this simplifies collecting the result a bit.
          with_peers(true) { |proxy| proxy.collect(me, sequence) }

          timeout = quorum_wait(:collected, sequence, RTT_TIMEOUT) do |remote_registry|
            remote_registry.each { |id, state| views[id].update(state) }
          end

          if timeout
            DCell::Logger.debug "Collect timeout"
          else
            collected(last_read_start_time)
            times -= 1
            sleep(READ_TIMEOUT)
          end
        end
      end
    end

    def collected(last_read_start_time)
      views.each do |id, view|
        view.update_expiration do |expired|
          DCell::Logger.debug "Cohort #{id} #{expired ? 'expired' : 'unexpired'}"
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

    def watchdog_process
      loop do
        if leading?
          pause(:watchdog)
          return if exiting?
        end
        captured = @ticks
        sleep(2 * REFRESH_TIMEOUT)
        if @ticks == captured
          DCell::Logger.debug "Watchdog timeout on #{@leader}"
          signal :collect
        end
      end
    end

    private

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
      if @leading != leading
        @leading = leading
        if @leading
          DCell::Logger.info "#{me} becoming leader #{@leader}"
          signal :refresh
        else
          DCell::Logger.info "#{me} lost leadership"
          signal :watchdog
        end
      end
    end

    def exiting?;    @exiting    end
    def leading?;    @leading    end
    def collecting?; @collecting end

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

    def crash
      raise "test crash"
    end
  end
end

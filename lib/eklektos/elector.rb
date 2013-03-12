module Eklektos
  class Elector
    include Celluloid
    extend Forwardable

    # Failure detection and leader election
    REFRESH_TIMEOUT = 12
    RTT_TIMEOUT     = 2
    READ_TIMEOUT    = REFRESH_TIMEOUT + RTT_TIMEOUT

    # The set of views for all cohorts, including its own view
    attr_reader :views

    # The set of all cohorts, including ourself
    attr_reader :cohorts

    def_delegators :"@views[DCell.id]", :epoch, :epoch=, :state, :state=, :view
    def_delegator :DCell, :id

    def initialize(*cohort_ids)
      cohort_ids.push DCell.id unless cohort_ids.include? DCell.id
      @cohorts = cohort_ids.inject({}) do |cohorts, cohort_id|
        cohorts[cohort_id] = Cohort.new(cohort_id)
        cohorts
      end
      @views = cohort_ids.inject({}) do |views, cohort_id|
        views[cohort_id] = View.new(State.new(Epoch.new(cohort_id)))
        views
      end
    end
  end
end

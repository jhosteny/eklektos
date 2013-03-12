module Eklektos
  class Cohort
    # The DCell id of the cohort
    attr_reader :id

    # The name of the remote actor
    attr_reader :name

    def initialize(id, name=:elector)
      @id = id
      @name = :elector
    end

    def actor
      unless @actor
        node   = DCell::Node[@id]
        @actor = node.find(@name) if node
      end
      @actor
    end

    def mailbox
      actor.mailbox
    end
  end
end

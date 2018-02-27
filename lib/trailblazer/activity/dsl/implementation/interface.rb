class Trailblazer::Activity < Module
  module Interface
    # @return [Process, Hash, Adds] Adds is private and should not be used in your application as it might get removed.
    def to_h # TODO: test me
      @state.to_h
    end

    def debug # TODO: TEST ME
      to_h[:debug]
    end

    def outputs
      to_h[:outputs]
    end
  end
end

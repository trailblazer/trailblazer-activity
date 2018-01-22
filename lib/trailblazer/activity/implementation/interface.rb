class Trailblazer::Activity < Module
  module Interface
    # @return [Process, Hash, Adds] Adds is private and should not be used in your application as it might get removed.
    def decompose # TODO: test me
      @state.to_h
    end

    def debug # TODO: TEST ME
      decompose[:debug]
    end

    def outputs
      decompose[:outputs]
    end
  end
end

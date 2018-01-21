module Trailblazer::Activity
  module Interface
    # @return [Process, Hash, Adds] Adds is private and should not be used in your application as it might get removed.
    def decompose # TODO: test me
      return @process, outputs, @adds, @builder
    end

    def debug # TODO: TEST ME
      @debug
    end

    def outputs
      @outputs
    end
  end
end

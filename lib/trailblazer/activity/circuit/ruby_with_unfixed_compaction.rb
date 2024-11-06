module Trailblazer
  class Activity
    # TODO: we can remove this once we drop Ruby <= 3.3.6.
    class Circuit
      # This is a hot fix for Ruby versions that haven't fixed the GC compaction bug:
      #   https://redmine.ruby-lang.org/issues/20853
      #   https://bugs.ruby-lang.org/issues/20868
      #
      # Affected versions might be: 3.1.x, 3.2.?????????, 3.3.0-3.3.6
      # You don't need this fix in the following versions: 
      #
      # If you experience this bug: https://github.com/trailblazer/trailblazer-activity/issues/60
      #
      #   NoMethodError: undefined method `[]' for nil
      #
      # you need to do 
      #
      #   Trailblazer::Activity::Circuit.include(RubyWithUnfixedCompaction)
      module RubyWithUnfixedCompaction
        def initialize(wiring, *args, **options)
          wiring.compare_by_identity

          super(wiring, *args, **options)
        end
      end
    end
  end
end

require "test_helper"

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1") && RUBY_ENGINE == "ruby"
  # TODO: we can remove this once we drop Ruby <= 3.3.6.
  class GCBugTest < Minitest::Spec
    it "still finds {.method} tasks after GC compression" do
      ruby_version = Gem::Version.new(RUBY_VERSION)

      activity = Fixtures.flat_activity() # {b} and {c} are {.method(:b)} tasks.

      signal, (ctx, _) = activity.([{seq: []}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})

      if ruby_version >= Gem::Version.new("3.1") && ruby_version < Gem::Version.new("3.2")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.2.0") && ruby_version <= Gem::Version.new("3.2.6")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.3.0") #&& ruby_version <= Gem::Version.new("3.3.6")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      end

      ruby_version_specific_options =
        if ruby_version >= Gem::Version.new("3.2") # FIXME: future
          {expand_heap: true, toward: :empty}
        else
          {}
        end

      # Provoke the bug:
      GC.verify_compaction_references(**ruby_version_specific_options)

      activity = Fixtures.flat_activity() # {b} and {c} are {.method(:b)} tasks.

      # Without the fix, this *might* throw the following exception:
      #
      # NoMethodError: undefined method `[]' for nil
      #     /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/circuit.rb:80:in `next_for'

      signal, (ctx, _) = activity.([{seq: []}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})
    end
  end
end

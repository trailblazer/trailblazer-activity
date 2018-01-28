require "test_helper"

class DocsOutputTest < Minitest::Spec
  describe "Output() with task: Activity" do
    it do
      nested = Module.new do
        extend Activity::FastTrack()

        step T.def_task(:a), fast_track: true # four ends.
      end

      activity = Module.new do
        extend Activity::Path()
puts "****"
        task Activity::DSL::Helper::Nested(nested),
          Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
      end
    end
  end
end

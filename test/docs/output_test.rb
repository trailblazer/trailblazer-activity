require "test_helper"

class DocsOutputTest < Minitest::Spec
  let(:nested) do
    Module.new do
      extend Activity::FastTrack()

      step T.def_task(:a), fast_track: true # four ends.
    end
  end

  describe "Output() with task: Activity" do
    it "allows to grab existing Output(:semantic) from nested activity" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Activity::DSL::Helper::Nested(nested),
          Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:my_pass_fast>


#<End/:success>

#<End/:my_pass_fast>
}
    end

    it "allows adding an additional plus pole to Nested's outputs" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Activity::DSL::Helper::Nested(nested),
          Output("Restart", :restart) => End(:restart) # references a plus pole from VV
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {Restart} => #<End/:restart>


#<End/:success>

#<End/:restart>
}
    end
  end
end

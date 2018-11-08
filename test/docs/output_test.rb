require "test_helper"

class DocsOutputTest < Minitest::Spec
  describe "plain task" do
    it "allows wiring existing default outputs" do
      activity = Module.new do
        extend Activity::Path()

        task "A",
          Output(:success) => End(:my_pass_fast)
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=A>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=A>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:my_pass_fast>
#<End/:success>

#<End/:my_pass_fast>
}
    end

    it "allows grabing explicitly passed output" do
      activity = Module.new do
        extend Activity::Path()

        task "A",
          Output(:pass) => End(:my_pass), outputs: { pass: Activity.Output("Pass", :pass), fail: Activity.Output("Fail", :fail) }
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=A>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=A>
 {Pass} => #<End/:my_pass>
#<End/:success>

#<End/:my_pass>
}
    end
  end


  describe "Subprocess" do
    let(:nested) do
      Module.new do
        extend Activity::FastTrack()

        step T.def_task(:a), fast_track: true # four ends.
      end
    end

    it "allows to grab existing Output(:semantic) from nested activity" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Subprocess(nested),
          Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:my_pass_fast>
#<End/:success>

#<End/:my_pass_fast>
}
    end

    it "allows adding an additional plus pole to Subprocess's outputs via Output(.. ,..)" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Subprocess(nested),
          Output("Restart", :restart) => End(:restart) # references a plus pole from VV
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:success>
 {Restart} => #<End/:restart>
#<End/:success>

#<End/:restart>
}
    end

    it "connects existing semantics, except for :failure (that's the point of #task)" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Subprocess(nested) # Subprocess() has a :pass_fast output.
        _end task: Trailblazer::Activity::End(:pass_fast), magnetic_to: [:pass_fast]
        _end task: Trailblazer::Activity::End(:fail_fast), magnetic_to: [:fail_fast]
        _end task: Trailblazer::Activity::End(:failure), magnetic_to: [:failure]
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:success>
#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>

#<End/:success>
}
    end

    it "connects existing semantics and allows connecting :failure" do
      nested = self.nested

      activity = Module.new do
        extend Activity::Path()

        task Subprocess(nested), Output(:failure) => Track(:failure) # Subprocess() has a :pass_fast output.
        _end task: Trailblazer::Activity::End(:pass_fast), magnetic_to: [:pass_fast]
        _end task: Trailblazer::Activity::End(:fail_fast), magnetic_to: [:fail_fast]
        _end task: Trailblazer::Activity::End(:failure), magnetic_to: [:failure]
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>

#<End/:success>
}
    end
  end
end

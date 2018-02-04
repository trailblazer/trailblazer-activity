require "test_helper"

class SubprocessTest < Minitest::Spec
  let(:nested) do
    Module.new do
      extend Activity::FastTrack()

      step T.def_task(:a), fast_track: true # four ends.
    end
  end

  it "connects two :plus_poles for a nested FastTrack" do
    nested = self.nested

    activity = Module.new do
      extend Activity::Path()

      task Subprocess(nested),
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

  it "allows overriding existing plus_pole via Output" do
    nested = self.nested

    activity = Module.new do
      extend Activity::Railway()

      step Subprocess(nested),
        Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:my_pass_fast>
#<End/:success>

#<End/:failure>

#<End/:my_pass_fast>
}
  end

  it "allows to reconnect nested outputs by grabbing those" do
        # collection.outputs[:failure] => :failure,
    # collection.outputs[:success] => :success
  end
end

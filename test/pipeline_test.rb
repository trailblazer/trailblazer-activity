require "test_helper"

class PipelineTest < Minitest::Spec
  it "provides {Pipeline()} builder method that receives a hash" do
    pipe = Trailblazer::Activity::Pipeline("a" => 1, "b" => 2)

    assert_equal pipe.to_a.inspect, %([["a", 1], ["b", 2]])
  end

  describe "Pipeline#call" do
    it "exposes a circuit interface and runs its steps with circuit interface, but ignores the returned signal, if there is any" do
# raise "is it clever to provide a call method for Pipeline? what if we wanted to use a Runner?"
      my_pipe_task = ->(ctx, flow_options, circuit_options) do
        ctx[:recorded] << [flow_options.inspect, circuit_options.inspect]

        # no signal returned
        return ctx, flow_options.merge(a: true)
      end

      my_task = ->(ctx, flow_options, circuit_options) do
        signal = 1
        ctx[:recorded] << [flow_options.inspect, circuit_options.inspect, signal]

        # this is a normal circuit interface return set.
        return ctx, flow_options.merge(b: true), signal
      end

      pipe = Trailblazer::Activity::Pipeline(a: my_pipe_task, b: my_task, c: my_pipe_task)

      ctx, flow_options, signal = pipe.({recorded: []}, {}, {stop: false})

      assert_equal CU.inspect(ctx), %({:recorded=>[["{}", "{:stop=>false}"], ["{:a=>true}", "{:stop=>false}", 1], ["{:a=>true, :b=>true}", "{:stop=>false}"]]})
      assert_equal CU.inspect(flow_options), %({:a=>true, :b=>true})
      assert_nil signal
    end
  end

  it "provides #find(id:)" do
    pipe = Trailblazer::Activity::Pipeline("a" => 1, "b" => Object)

    assert_equal Trailblazer::Activity::Pipeline.find(pipe, id: "b"), Object
    assert_equal Trailblazer::Activity::Pipeline.find(pipe, id: nil).inspect, %(nil)
  end
end

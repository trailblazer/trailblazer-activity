require "test_helper"
require "trailblazer/circuit/trace"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  SpecialDirection = Class.new

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }
  Save  = ->(direction, options, flow_options) { options["saved"]=true;   [direction, options, flow_options] }
  Upload = ->(direction, options, flow_options) { options["bits"]=64;   [direction, options, flow_options] }
  Cleanup  = ->(direction, options, flow_options) { options["ok"]=true;   [direction, options, flow_options] }

  MyInject = ->(direction, options, flow_options) { [direction, options.merge( current_user: Module ), flow_options] }

  class Pipeline
    class Start < Circuit::Start
    end

    class End < Circuit::End
      def call(direction, options, flow_options)
        [flow_options[:result_direction], options, flow_options]
      end
    end
    Input  = ->(direction, options, flow_options) { [direction, options, flow_options] }
      # FIXME: wrong direction and flow_options here!
    Call   = ->(direction, options, flow_options) {
      step  = flow_options[:step]
      debug = flow_options[:debug]
      is_nested = step.instance_of?(Circuit::Nested)

      flow_options[:result_direction], options, flow_options = step.( direction, options,
        # FIXME: only pass :runner to nesteds.
              is_nested ? flow_options.merge( runner: flow_options[:_runner], debug: step.activity.circuit.instance_variable_get(:@name) ) : flow_options )

      [ direction, options, flow_options.merge( step: step, debug: debug ) ]
    }
    Output = ->(direction, options, flow_options) { [direction, options, flow_options] }

    Step = Circuit::Activity({ id: "runner/pipeline.default" },
        start: { default: Start.new(:default) },
        end: { default: End.new(:default) }) do |act|
      {
        act[:Start]          => { Circuit::Right => Call },                  # options from outside
        # Input                => { Circuit::Right => Trace::CaptureArgs },
        # MyInject               => { Circuit::Right => Trace::CaptureArgs },
        # Trace::CaptureArgs   => { Circuit::Right => Call  },
        Call                 => { Circuit::Right => act[:End] },
        # Trace::CaptureReturn => { Circuit::Right => Output },
        # Output               => { Circuit::Right => act[:End] }
      }
    end


    # Find the respective pipeline per step and run it.
    class Runner
      def self.call(step, direction, options, runner:, **flow_options)
        step_runner = flow_options[:step_runners][step] || flow_options[:step_runners][nil] # DISCUSS: default could be more explicit@

        # we can't pass :runner in here since the Step::Pipeline would call itself again, then.
        # However, we need the runner in nested activities.
        pipeline_options = flow_options.merge( step: step, _runner: Runner )

        # Circuit#call
        step_runner.( step_runner[:Start], options, pipeline_options )
      end
    end
  end

  let (:activity) do
    Circuit::Activity(id: "bla") do |act|
      {
        act[:Start] => { Circuit::Right => Model },
        Model       => { Circuit::Right => Uuid },
        Uuid        => { SpecialDirection => act[:End] }
      }
    end
  end

  it do
    # FIXME: inserts CaptureArgs wrongly if not-existent before
    # model_pipe = Circuit::Activity::Before( Pipeline::Step, Trace::CaptureArgs, MyInject, direction: Circuit::Right )
    model_pipe = Pipeline::Step
# put Pipeline::Step

    # this is done by Operation/Activity
    step_runners = {
      nil   => Pipeline::Step,
      Model => model_pipe,
      Uuid  => Pipeline::Step,
    }

    direction, options, flow_options = activity.(activity[:Start], options = {}, { runner: Pipeline::Runner, stack: stack=[], step_runners: step_runners })

    direction.must_equal activity[:End] # the actual activity's End signal.
    options  .must_equal({"model"=>String, "uuid"=>999})

    stack.must_equal []
  end

  #- tracing
  let (:with_tracing) do
    model_pipe = Circuit::Activity::Before( Pipeline::Step, Pipeline::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right )
    model_pipe = Circuit::Activity::Before( model_pipe, Pipeline::Step[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right )
  end

  it "traces flat" do
    step_runners = {
      nil   => Pipeline::Step,
      Model => with_tracing,
      Uuid  => with_tracing,
    }

    direction, options, flow_options = activity.(activity[:Start], options = {}, { runner: Pipeline::Runner, stack: stack=[], step_runners: step_runners })

    direction.must_equal activity[:End] # the actual activity's End signal.
    options  .must_equal({"model"=>String, "uuid"=>999})

    stack.must_equal(
    [
      # [activity[:Start], :args, nil, {}],
      [Model,            :args, nil, {}],
      [Model,            :return, Circuit::Right, { "model"=>String }],
      [Uuid,             :args, nil, { "model"=>String }],
      [Uuid,             :return, SpecialDirection, { "model"=>String, "uuid"=>999 }],
      # DISCUSS: do we want the tmp vars around here?
      # [activity[:End],   :args, nil, {:current_user=>Module, "model"=>String, "uuid"=>999}]
    ])
  end

  describe "nested trailing" do
    let (:more_nested) do
      Circuit::Activity(id: "more_nested") do |act|
        {
          act[:Start] => { Circuit::Right => Upload },
          Upload        => { Circuit::Right => act[:End] }
        }
      end
    end

    let (:nested) do
      Circuit::Activity(id: "nested") do |act|
        {
          act[:Start] => { Circuit::Right    => Save },
          Save        => { Circuit::Right    => __nested = Circuit::Nested(more_nested) },
          __nested    => { more_nested[:End] => Cleanup },
          Cleanup     => { Circuit::Right => act[:End] }
        }
      end
    end

    let (:activity) do
      Circuit::Activity(id: "outsideg") do |act|
        {
          act[:Start] => { Circuit::Right => Model },
          Model       => { Circuit::Right => __nested = Circuit::Nested( nested ) },
          __nested    => { nested[:End] => Uuid },
          Uuid        => { SpecialDirection => act[:End] }
        }
      end
    end

    it "trail" do
      step_runners = {
        # nil   => Pipeline::Step,
        nil   => with_tracing,
      }

      direction, options, flow_options = activity.(
        activity[:Start],
        options = {},
        { runner: Pipeline::Runner, stack: Circuit::Trace::Stack.new, step_runners: step_runners, debug: activity.circuit.instance_variable_get(:@name) })

      direction.must_equal activity[:End] # the actual activity's End signal.
      options  .must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})

      # require "pp"
      # pp flow_options[:stack].to_a

      flow_options[:stack].to_a[2][0].last.must_equal({:id=>"outsideg"})
      flow_options[:stack].to_a[2][1].first.last.must_equal({:id=>"nested"})
      flow_options[:stack].to_a[3][0].last.must_equal({:id=>"outsideg"})





      require "trailblazer/circuit/present"

      puts Circuit::Trace::Present.tree(flow_options[:stack].to_a)




      flow_options[:stack].to_a.must_equal(
      [
        # [activity[:Start], :args, nil, {}],
        [Model,            :args, nil, {}],
        [Model,            :return, Circuit::Right, { "model"=>String }],
        [Uuid,             :args, nil, { "model"=>String }],
        [Uuid,             :return, SpecialDirection, { "model"=>String, "uuid"=>999 }],
        # DISCUSS: do we want the tmp vars around here?
        # [activity[:End],   :args, nil, {:current_user=>Module, "model"=>String, "uuid"=>999}]
      ])
    end
  end
end

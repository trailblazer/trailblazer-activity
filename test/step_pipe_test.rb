require "test_helper"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  SpecialDirection = Class.new

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }

  MyInject = ->(direction, options, flow_options) { [direction, options.merge( current_user: Module ), flow_options] }

  module Trace
    CaptureArgs   = ->(direction, options, flow_options) { flow_options[:stack] << [flow_options[:step], :args,   options.dup]; [direction, options, flow_options] }
    CaptureReturn = ->(direction, options, flow_options) { flow_options[:stack] << [flow_options[:step], :return, flow_options[:result_direction], options.dup]; [direction, options, flow_options] }
  end

  class Pipeline
    class End < Circuit::End
      def call(direction, options, flow_options)
        put :c, flow_options[:result_direction]
        [flow_options[:result_direction], options, flow_options]
      end
    end
    Input  = ->(direction, options, flow_options) { [direction, options, flow_options] }
      # FIXME: wrong direction and flow_options here!
    Call   = ->(direction, options, flow_options) { flow_options[:result_direction], options, flow_options = flow_options[:step].( direction, options, flow_options ); [ direction, options, flow_options]  }
    Output = ->(direction, options, flow_options) { [direction, options, flow_options] }

    Step = Circuit::Activity({ id: "runner/pipeline.default" }, end: { default: End.new(:default) }) do |act|
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
      def self.call(step, direction, options, flow_options)
        # put step

        # DISCUSS: step_runner is an activity.
        step_runner = flow_options[:step_runners][step] || flow_options[:step_runners][nil] # DISCUSS: default could be more explicit@

        pipeline_options = { step: step, stack: flow_options[:stack], step_runners: flow_options[:step_runners] }
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
  it "traces" do
    model_pipe = Circuit::Activity::Before( Pipeline::Step, Pipeline::Call, Trace::CaptureArgs, direction: Circuit::Right )
    model_pipe = Circuit::Activity::Before( model_pipe, Pipeline::Step[:End], Trace::CaptureReturn, direction: Circuit::Right )

    step_runners = {
      nil   => Pipeline::Step,
      Model => model_pipe,
      Uuid  => model_pipe,
    }

    direction, options, flow_options = activity.(activity[:Start], options = {}, { runner: Pipeline::Runner, stack: stack=[], step_runners: step_runners })

    direction.must_equal activity[:End] # the actual activity's End signal.
    options  .must_equal({"model"=>String, "uuid"=>999})

    stack.must_equal(
    [
      # [activity[:Start], :args, {}],
      [Model,            :args, {}],
      [Model,            :return, Circuit::Right, { "model"=>String }],
      [Uuid,             :args, { "model"=>String }],
      [Uuid,             :return, SpecialDirection, { "model"=>String, "uuid"=>999 }],
      # DISCUSS: do we want the tmp vars around here?
      # [activity[:End],   :args, {:current_user=>Module, "model"=>String, "uuid"=>999}]
    ])
  end
end

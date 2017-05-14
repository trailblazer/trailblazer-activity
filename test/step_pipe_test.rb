require "test_helper"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  SpecialDirection = Class.new

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }

  module Trace
    CaptureArgs   = ->(direction, options, flow_options) { flow_options[:stack] << options; [direction, options, flow_options] }
    CaptureReturn = ->(direction, options, flow_options) { flow_options[:stack] << [options[:result_direction], options]; [direction, options, flow_options] }
  end

  class Pipeline
    class End < Circuit::End
      def call(direction, options, flow_options)
        put :c, flow_options[:result_direction]
        [flow_options[:result_direction], options, flow_options]
      end
    end
    Input  = ->(direction, options, flow_options) { [direction, options, flow_options] }
    Inject = ->(direction, options, flow_options) { [direction, options.merge( a: Module ), flow_options] }
      # FIXME: wrong direction and flow_options here!
    Call   = ->(direction, options, flow_options) { flow_options[:result_direction], options, flow_options = flow_options[:step].( direction, options, flow_options ); [ direction, options, flow_options]  }
    Output = ->(direction, options, flow_options) { [direction, options, flow_options] }

    Step = Circuit::Activity({ id: "runner/pipeline.default" }, end: { default: End.new(:default) }) do |act|
      {
        act[:Start]          => { Circuit::Right => Input },
        Input                => { Circuit::Right => Inject },
        Inject               => { Circuit::Right => Trace::CaptureArgs },
        Trace::CaptureArgs   => { Circuit::Right => Call },
        Call                 => { Circuit::Right => Trace::CaptureReturn },
        Trace::CaptureReturn => { Circuit::Right => Output },
        Output               => { Circuit::Right => act[:End] }
      }
    end


    class Runner
      def self.call(step, direction, options, flow_options)
        # put step

        pipeline_options = { step: step, stack: flow_options[:stack] }
        Pipeline::Step.( Pipeline::Step[:Start], options, pipeline_options )
      end
    end
  end

  it do
    activity = Circuit::Activity(id: "bla") do |act|
      {
        act[:Start] => { Circuit::Right => Model },
        Model       => { Circuit::Right => Uuid },
        Uuid        => { SpecialDirection => act[:End] }
      }
    end

    activity.(activity[:Start], options = {}, { runner: Pipeline::Runner, stack: [] })
  end
end

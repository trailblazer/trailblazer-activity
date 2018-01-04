require "test_helper"

module Trailblazer
  module Activity::TaskWrap
    class StaticWrapExtension
      def initialize(extension_adds)
        @extension_adds = extension_adds
      end

      def call(activity, adds, task:, **returned_options)
        static_wrap = activity["__static_task_wraps__"][task]

        # macro might want to apply changes to the static task_wrap (e.g. Inject)
        activity["__static_task_wraps__"][task] = Activity::Magnetic::Builder.merge( static_wrap, @extension_adds )
      end
    end
  end
end

class TaskWrapMacroTest < Minitest::Spec
  TaskWrap = Trailblazer::Activity::TaskWrap
  Builder  = Trailblazer::Activity::Magnetic::Builder

  #
  # {TaskWrap API} extension task
  TaskWrap_Extension_task = ->( (wrap_config, original_args), **circuit_options ) do
    (ctx, b), c = original_args

    ctx[:before_call] = ctx[:i] + 1

    return Trailblazer::Activity::Right, [ wrap_config, [[ctx, b], c] ]
  end

  #
  # {Macro} extending the task wrap
  def self.Macro_StaticWrapExtension( task )
    extension_adds = Builder::Path.plan do
      task TaskWrap_Extension_task, id: "before_call", before: "task_wrap.call_task" # i + 1
    end

    { id: "with_static", task: task, extension: [ TaskWrap::StaticWrapExtension.new(extension_adds) ] }
  end

  #
  # Actual {Activity} using the {Macro}
  class Create < Trailblazer::Activity
    def self.add_1_to_i(args)
      raise args.inspect
    end

    task TaskWrapMacroTest.Macro_StaticWrapExtension( method(:add_1_to_i) )
  end

  it do
    event, options, flow_options = Create.( [{ i: 1 }, {}], {} )
  end
end

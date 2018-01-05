require "test_helper"

module Trailblazer
  module Activity::TaskWrap
    class StaticWrapExtension
      def initialize(extension_adds)
        @extension_adds = extension_adds
      end

      def call(activity, adds, original_task, local_options, *returned_options)
        # static_wrap = activity["__static_task_wraps__"][task]

        # # macro might want to apply changes to the static task_wrap (e.g. Inject)
        # activity["__static_task_wraps__"][task] = Activity::Magnetic::Builder.merge( static_wrap, @extension_adds )

        activity.task activity.method(:b), id: "add_another_1", before: local_options[:id]
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

  # Sample {Extension}
  SampleExtension = ->(activity, adds, original_task, local_options, *returned_options) do
    activity.task activity.method(:b), id: "add_another_1", before: local_options[:id]
  end

  #
  # Actual {Activity} using the {Macro}
  class Create < Trailblazer::Activity
    def self.a( (ctx, flow_options), **)
      ctx[:seq] << :a

      return Right, [ ctx, flow_options ]
    end

    def self.b( (ctx, flow_options), **)
      ctx[:seq] << :b

      return Right, [ ctx, flow_options ]
    end

    # extension_adds = Builder::Path.plan do
    #   task TaskWrap_Extension_task, id: "before_call", before: "task_wrap.call_task" # i + 1
    # end

    task method(:a),
      id:        "add_1",
      extension: [
        SampleExtension
      ]
  end

  it "runs two tasks" do
    event, (options, flow_options) = Create.( [{ seq: [] }, {}], {} )

    options.must_equal( {:seq=>[:b, :a]} )
  end

end

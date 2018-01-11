module Trailblazer
  module Activity::TaskWrap
    # This is instantiated via the DSL, and passed to the :extension API,
    # allowing to add steps to the Activity's static_wrap.
    class Merge
      def initialize(extension_adds)
        @extension_adds = extension_adds
      end

      # {:extension API}
      def call(activity, task, local_options, *returned_options)
        static_wrap = activity.static_task_wrap[task]

        # # macro might want to apply changes to the static task_wrap (e.g. Inject)
        activity.static_task_wrap[task] = Activity::Magnetic::Builder.merge( static_wrap, @extension_adds )
      end
    end
  end
end

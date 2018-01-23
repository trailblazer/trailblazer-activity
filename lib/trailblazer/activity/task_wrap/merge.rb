module Trailblazer
  module Activity::TaskWrap
    # This is instantiated via the DSL, and passed to the :extension API,
    # allowing to add steps to the Activity's static_wrap.
    class Merge
      def initialize(extension_plan)
        @extension_plan = extension_plan
      end

      # {:extension API}
      def call(activity, task, local_options, *returned_options)
        # we could make the default initial_activity injectable via the DSL, the value would sit in returned_options or local_options.
        static_wrap = Activity::TaskWrap.wrap_static_for(task, wrap_static: activity[:wrap_static] || {})

        # # macro might want to apply changes to the static task_wrap (e.g. Inject)
        new_wrap =  Activity::Path::Plan.merge( static_wrap, @extension_plan )

        activity[:wrap_static, task] = new_wrap
      end
    end
  end
end

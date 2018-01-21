module Trailblazer::Activity
  # Implementation module that can be passed to `Activity[]`.
  module Path
    # Default variables, called in {Activity::[]}.
    def self.config
      {
        builder_class:    Magnetic::Builder::Path, # we use the Activity-based Normalizer
        normalizer_class: Magnetic::Normalizer,
        plus_poles:       Magnetic::Builder::Path.default_plus_poles,
        extension:        [ Introspect.method(:add_introspection) ],
      }
    end

    # @import FastTrack::build_state_for
    extend BuildState
    # @import =>Path#call
    include PublicAPI

    # @import =>Path#task
    include DSL.def_dsl(:task)

    module Plan
      def self.extended(extended)
        extended.singleton_class.send :attr_accessor, :record
        extended.record = []
      end

      def task(*args, &block)
        record << [:task, args, block]
      end

      def self.merge!(activity, plan)
        plan.record.each { |(dsl_method, args, block)| activity.send(dsl_method, *args, &block)  }
        activity
      end

      # Creates a copy of the {activity} module and merges the {Plan} into it.
      #
      # @params activity [Activity] The activity to extend
      # @params plan [Plan] The plan providing additional steps
      # @return [Activity] A new, merged activity
      def self.merge(activity, plan)
        merge!(activity.clone, plan)
      end
    end
  end
end


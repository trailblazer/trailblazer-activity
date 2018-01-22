module Trailblazer
  class Activity < Module
    def self.Path(options={})
      Activity::Path.new(Path, options)
    end

    # Implementation module that can be passed to `Activity[]`.
    class Path < Activity
      # Default variables, called in {Activity::initialize}.
      def self.config
        {
          builder_class:    Magnetic::Builder::Path, # we use the Activity-based Normalizer
          normalizer_class: Magnetic::Normalizer,
          plus_poles:       Magnetic::Builder::Path.default_plus_poles,
          extension:        [ Introspect.method(:add_introspection) ],

          extend:           [ DSL.def_dsl(:task) ],
        }
      end

      def self.Plan()
        Plan
      end

      module Plan
        def self.extended(extended)
          extended.singleton_class.send :attr_accessor, :record
          extended.record = []
          extended.extend(Methods)
        end

        module Methods
          def task(*args, &block)
            record << [:task, args, block]
          end
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
end


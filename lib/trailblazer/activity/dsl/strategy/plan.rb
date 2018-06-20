module Trailblazer
  class Activity::Path < Activity
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
        plan.record.each { |(dsl_method, args, block)| activity.send(dsl_method, *args, &block) }
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


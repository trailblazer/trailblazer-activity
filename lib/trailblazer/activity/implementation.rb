module Trailblazer
  class Activity
    # Provides DSL and compilation for a {Schema::Implementation}
    # maintaining the actual tasks for a {Schema::Intermediate}.
    #
    # Exposes {Activity::Interface} so this can be used directly in other
    # workflows.
    #
    # NOTE: Work in progress!
    class Implementation
      def self.implement(intermediate, id2cfg)

        outputs_defaults = { # TODO: make this injectable and allow passing more.
          success: Activity::Output(Activity::Right, :success),
          failure: Activity::Output(Activity::Left,  :failure),
        }

        # automatically create {End}s.
        ends = intermediate.stop_task_refs
        ends_outputs = ends.collect { |ref| intermediate.wiring.find { |_ref, connections| _ref.id == ref.id } } # FIXME
        ends = ends_outputs.collect { |ref, (output, _)| [ref.id, {output.semantic => Activity::Output(Activity::End(output.semantic), output.semantic)}] }
        ends = Hash[ends]

        # raise ends.inspect

        step_interface_builder = TaskBuilder.method(:Binary)

        implementation = id2cfg.collect do |id, cfg|
          # TODO: ALLOW macro
          task = cfg

          task = step_interface_builder.(cfg)

          outputs = outputs_for_task(intermediate, task: task, id: id, outputs_defaults: outputs_defaults, task_outputs: ends)

          [id, Schema::Implementation::Task(task, outputs)]
        end

        implementation = Hash[implementation]

        pp implementation

        implementation
      end

      def self.outputs_for_task(intermediate, task:, id:, outputs_defaults:, task_outputs:)
        connections = find_outputs(intermediate, id)

        outputs = connections.collect { |connection|
          semantic = connection.semantic
# FIXME:
          output   = task_outputs[id]&&task_outputs[id][semantic]
          output ||= outputs_defaults[semantic] or raise

        }
      end

      def self.find_outputs(intermediate, id)
        ref, connections = intermediate.wiring.find { |ref, connections| ref.id == id }
        connections
      end

=begin
    implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Schema::Implementation::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Schema::Implementation::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Schema::Implementation::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }
=end


      def self.call(*args) # FIXME: shouldn't this be coming from Activity::Interface?
        @activity.(*args)
      end
    end

  end
end

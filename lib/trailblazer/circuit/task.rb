class Trailblazer::Circuit
  module Task
    module_function
    # Convenience functions for tasks. Totally optional.

    # Task::Binary aka "step"
    # Step is binary task: true=> Right, false=>Left.
    # Step call proc.(options, flow_options)
    # Step is supposed to run Option::KW, so `step` should be Option::KW.
    #
    # Returns task to call the proc with (options, flow_options), omitting `direction`.
    # When called, the task always returns a direction signal.
    def Binary(step, on_true=Right, on_false=Left)
      ->(*args) do # Activity/Task interface.
        [ step.(*args) ? on_true : on_false, options, flow_options ] # <=> Activity/Task interface
      end
    end

    module Args
      module_function
      # :private:
      # Return task to call the proc with keyword arguments. Ruby >= 2.0.
      # This is used by `Operation::step` to wrap the argument and make it
      # callable in the circuit.
      def KW(proc)
        if proc.is_a? Symbol
          ->(*args) { meth!(proc, *args) } # Activity interface
        else
          ->(*args) { call!(proc, *args) } # Activity interface
        end
      end

      # DISCUSS: standardize tmp_options.
      # Calls `proc` with a step interface.
      def call!(proc, direction, options, flow_options, tmp_options={})
        proc.(options, **options.to_hash(tmp_options))
      end

      # Make the context's instance method a "lambda" and reuse #call!.
      # TODO: should we make :context a kwarg?
      def meth!(proc, direction, options, flow_options, *args)
        call!(flow_options[:context].method(proc), options, flow_options, *args)
      end
    end
  end
end

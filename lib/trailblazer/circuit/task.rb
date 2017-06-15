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
      ->(direction, *args) do # Activity/Task interface.
        [ step.(direction, *args) ? on_true : on_false, *args ] # <=> Activity/Task interface
      end
    end

    module Args
      # Returns a {Proc} that, when called, invokes the `proc` argument with keyword arguments.
      # This is known as "step (call) interface".
      #
      # This is commonly used by `Operation::step` to wrap the argument and make it
      # callable in the circuit.
      #
      #   my_proc = ->(options, **kws) { options["i got called"] = true }
      #   task    = Trailblazer::Circuit::Args::KW(my_proc)
      #   task.(options = {})
      #   options["i got called"] #=> true
      #
      # Alternatively, you can pass a symbol and an `:exec_context`.
      #
      #   my_proc = :some_method
      #   task    = Trailblazer::Circuit::Args::KW(my_proc)
      #
      #   class A
      #     def some_method(options, **kws)
      #       options["i got called"] = true
      #     end
      #   end
      #
      #   task.(options = {}, exec_context: A.new)
      #   options["i got called"] #=> true
      def self.KW(proc)
        if proc.is_a? Symbol
          ->(*args) { meth!(proc, *args) } # Activity interface
        else
          ->(*args) { call!(proc, *args) } # Activity interface
        end
      end

      # Calls `proc` with a "step" interface.
      def self.call!(proc, direction, options, flow_options, *args)
        proc.(options, **options.to_hash)
      end

      # Make the context's instance method a "lambda" and reuse #call!.
      # TODO: should we make :context a kwarg?
      def self.meth!(proc, direction, options, flow_options, *args)
        call!(flow_options[:exec_context].method(proc), direction, options, flow_options, *args)
      end

      private_class_method :call!, :meth!
    end
  end
end

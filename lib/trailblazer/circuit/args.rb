module Trailblazer
  class Circuit
    class Args
      class << self
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
        def KW(proc)
          if proc.is_a? Symbol
            ->(*args) { meth!(proc, *args) } # Task interface
          else
            ->(*args) { call!(proc, *args) } # Task interface
          end
        end

        private

        # Calls `proc` with a "step" interface.
        def call!(proc, options, flow_options)
          proc.(options, **options.to_hash)
        end

        # Make the context's instance method a "lambda" and reuse #call!.
        # TODO: should we make :context a kwarg?
        def meth!(proc, options, flow_options)
          call!(flow_options[:exec_context].method(proc), options, flow_options)
        end
      end
    end
  end

end

module Trailblazer
  # @note This might go to trailblazer-args along with `Context` at some point.
  class Args
    class << self
      # Returns a {Proc} that, when called, invokes the `proc` argument with keyword arguments.
      # This is known as "step (call) interface".
      #
      # This is commonly used by `Operation::step` to wrap the argument and make it
      # callable in the circuit.
      #
      #   my_proc = ->(options, **kws) { options["i got called"] = true }
      #   task    = Trailblazer::Args::KW(my_proc)
      #   task.(options = {})
      #   options["i got called"] #=> true
      #
      # Alternatively, you can pass a symbol and an `:exec_context`.
      #
      #   my_proc = :some_method
      #   task    = Trailblazer::Args::KW(my_proc)
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
          ->(*args) { call_method!(proc, *args) }
        else
          ->(*args) { call_callable!(proc,   *args) }
        end
      end

      private

      # Calls `proc` with a "step" interface.
      # Override this for your own step strategy.
      def call!(proc, options)
        proc.(options, **options.to_hash) # Step interface: (options, **)
      end

      # Note that both #call_callable! and #call_method! drop most of the args.
      # If you need those, override this class.
      def call_callable!(proc, options, *)
        call!(proc, options)
      end

      # Make the context's instance method a "lambda" and reuse #call!.
      def call_method!(proc, options, exec_context:raise, **)
        call!(exec_context.method(proc), options)
      end
    end
  end
end

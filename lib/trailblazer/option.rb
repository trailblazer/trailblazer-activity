# TODO: test all this, for christ's sake.

module Trailblazer
  # @note This might go to trailblazer-args along with `Context` at some point.
  def self.Option(proc)
    Option.build(Option, proc)
  end

  class Option
    # Generic builder for a callable "option".
    # @param implementation [Class, Module] implements the process of calling the proc
    #   while passing arguments/options to it in a specific style (e.g. kw args, step interface).
    # @return [Proc] when called, this proc will evaluate its option (at run-time).
    def self.build(implementation, proc)
      if proc.is_a? Symbol
        ->(*args) { implementation.call_method!(proc, *args) }
      else
        ->(*args) { implementation.call_callable!(proc, *args) }
      end
    end

    # Calls `proc.(*args)` forwarding all arguments.
    # Override this for your own step strategy (see KW#call!).
    # @private
    def self.call!(proc, *args)
      proc.(*args)
    end

    # Note that both #call_callable! and #call_method! drop most of the args.
    # If you need those, override this class.
    # @private
    def self.call_callable!(proc, *args)
      call!(proc, *args)
    end

    # Make the context's instance method a "lambda" and reuse #call!.
    # @private
    def self.call_method!(proc, *args, exec_context:raise, **flow_options)
      call!(exec_context.method(proc), *args)
    end

    # Returns a {Proc} that, when called, invokes the `proc` argument with keyword arguments.
    # This is known as "step (call) interface".
    #
    # This is commonly used by `Operation::step` to wrap the argument and make it
    # callable in the circuit.
    #
    #   my_proc = ->(options, **kws) { options["i got called"] = true }
    #   task    = Trailblazer::Option::KW(my_proc)
    #   task.(options = {})
    #   options["i got called"] #=> true
    #
    # Alternatively, you can pass a symbol and an `:exec_context`.
    #
    #   my_proc = :some_method
    #   task    = Trailblazer::Option::KW(my_proc)
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
      Option.build(KW, proc)
    end

    class KW < Option
      # Calls `proc` with a "step interface".
      # @private
      def self.call!(proc, options, *)
        proc.(options, **options.to_hash) # Step interface: (options, **)
      end
    end
  end
end

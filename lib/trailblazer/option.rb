module Trailblazer
  # @note This might go to trailblazer-args along with `Context` at some point.
  def self.Option(proc)
    Option.build(Option, proc)
  end

  class Option
    # Generic builder for a callable "option".
    # @param call_implementation [Class, Module] implements the process of calling the proc
    #   while passing arguments/options to it in a specific style (e.g. kw args, step interface).
    # @return [Proc] when called, this proc will evaluate its option (at run-time).
    def self.build(call_implementation, proc)
      if proc.is_a? Symbol
        ->(*args) { call_implementation.evaluate_method(proc, *args) }
      else
        ->(*args) { call_implementation.evaluate_callable(proc, *args) }
      end
    end

    # A call implementation invoking `proc.(*args)` and plainly forwarding all arguments.
    # Override this for your own step strategy (see KW#call!).
    # @private
    def self.call!(proc, *args)
      proc.(*args)
    end

    # Note that both #evaluate_callable and #evaluate_method drop most of the args.
    # If you need those, override this class.
    # @private
    def self.evaluate_callable(proc, *args, **flow_options)
      call!(proc, *args)
    end

    # Make the context's instance method a "lambda" and reuse #call!.
    # @private
    def self.evaluate_method(proc, *args, exec_context:raise, **flow_options)
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

    # TODO: It would be cool if call! was typed and had `options SymbolizedHash` or something.
    class KW < Option
      # A different call implementation that calls `proc` with a "step interface".
      #   your_code.(options, **options)
      # @private
      def self.call!(proc, options, *)
        proc.(options, **options.to_hash) # Step interface: (options, **)
      end
    end
  end
end

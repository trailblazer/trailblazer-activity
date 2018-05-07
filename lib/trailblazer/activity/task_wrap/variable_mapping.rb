require "trailblazer/context"

class Trailblazer::Activity < Module
  module TaskWrap
    # TaskWrap step to compute the incoming {Context} for the wrapped task.
    # This allows renaming, filtering, hiding, of the options passed into the wrapped task.
    #
    # Both Input and Output are typically to be added before and after task_wrap.call_task.
    #
    # @note Assumption: we always have :input _and_ :output, where :input produces a Context and :output decomposes it.
    class Input
      def initialize(filter)
        @filter = filter
      end

      # `original_args` are the actual args passed to the wrapped task: [ [options, ..], circuit_options ]
      #
      def call( (wrap_ctx, original_args), circuit_options )
        # let user compute new ctx for the wrapped task.
        input_ctx = apply_filter(*original_args) # FIXME: THIS SHOULD ALWAYS BE A _NEW_ Context.
        # TODO: make this unnecessary.
        # wrap user's hash in Context if it's not one, already (in case user used options.merge).
        # DISCUSS: should we restrict user to .merge and options.Context?
        # input_ctx = Trailblazer.Context(input_ctx) #if !input_ctx.instance_of?(Trailblazer::Context) || input_ctx==original_args[0][0]

        wrap_ctx = wrap_ctx.merge( vm_original_ctx: original_args[0][0] ) # remember the original ctx

        # decompose the original_args since we want to modify them.
        (original_ctx, original_flow_options), original_circuit_options = original_args

        # instead of the original Context, pass on the filtered `input_ctx` in the wrap.
        return Trailblazer::Activity::Right, [ wrap_ctx, [[input_ctx, original_flow_options], original_circuit_options] ]
      end

      private

      def apply_filter((ctx, original_flow_options), original_circuit_options)
        new_ctx = @filter.( ctx, original_circuit_options )
        raise new_ctx.inspect unless new_ctx.is_a?(Trailblazer::Context)
        new_ctx
      end

      def self.Scoped(filter)
        Input.new(
          Scoped.new( Trailblazer::Option(filter) )
        )
      end

      class Scoped
        def initialize(filter)
          @filter = filter
        end

        def call(original_ctx, circuit_options)
          Trailblazer::Context(
            @filter.(original_ctx, **circuit_options)
          )
        end
      end

      def self.FromDSL(map)
        hsh = DSL.hash_for(map)

        Scoped( ->(original_ctx) { Hash[hsh.collect { |from_name, to_name| [to_name, original_ctx[from_name]] }].tap do |b|
          puts "@@@@@ #{b.inspect}"
        end } )
      end

    end

    module DSL
      def self.hash_for(ary)
        return ary if ary.instance_of?(::Hash)
        Hash[ary.collect { |name| [name, name] }]
      end
    end

    def self.Input(filter)
      Input.new( Trailblazer::Option(filter) )
    end

    def self.Output(filter)
      Output.new( Trailblazer::Option(filter) )
    end


    # TaskWrap step to compute the outgoing {Context} from the wrapped task.
    # This allows renaming, filtering, hiding, of the options returned from the wrapped task.
    class Output
      def initialize(filter, strategy=CopyMutableToOriginal)
        @filter   = filter
        @strategy = strategy
      end

      # Runs the user filter and replaces the ctx in `wrap_ctx[:return_args]` with the filtered one.
      def call( (wrap_ctx, original_args), **circuit_options )
        (original_ctx, original_flow_options), original_circuit_options = original_args

        returned_ctx, _ = wrap_ctx[:return_args] # this is the Context returned from `call`ing the task.

        # returned_ctx is the Context object from the nested operation. In <=2.1, this might be a completely different one
        # than "ours" we created in Input. We now need to compile a list of all added values. This is time-intensive and should
        # be optimized by removing as many Context creations as possible (e.g. the one adding self[] stuff in Operation.__call__).
        # _, mutable_data = returned_ctx.decompose # DISCUSS: this is a weak assumption. What if the task returns a deeply nested Context?

        original_ctx = wrap_ctx[:vm_original_ctx]

        # let user compute the output.
        output_ctx = @filter.(original_ctx, returned_ctx, **original_circuit_options)
        # output_ctx = apply_filter(returned_ctx, original_flow_options, original_circuit_options)

        # new_ctx = @strategy.( original_ctx, output ) # here, we compute the "new" options {Context}.

        wrap_ctx = wrap_ctx.merge( return_args: [output_ctx, original_flow_options] )

        # and then pass on the "new" context.
        return Trailblazer::Activity::Right, [ wrap_ctx, original_args ]
      end

      private

      # "merge" Strategy
      module CopyMutableToOriginal
        # @param original Context
        # @param options  Context The object returned from a (nested) {Activity}.
        def self.call(original, mutable)
          mutable.each { |k,v| original[k] = v }

          original
        end
      end

      def self.Unscoped(filter)
        Output.new(
          Unscoped.new( Trailblazer::Option(filter) )
        )
      end

      class Unscoped
        def initialize(filter)
          @filter = filter
        end

        def call(original_ctx, new_ctx, **circuit_options)
          _, mutable_data = new_ctx.decompose

          #   # "strategy" and user block
          original_ctx.merge(
            @filter.(new_ctx, **circuit_options)
          )
        end
      end

      def self.FromDSL(map)
        hsh = DSL.hash_for(map)

        Unscoped( ->(new_ctx) { Hash[hsh.collect { |from_name, to_name|
          [to_name, new_ctx[from_name]] }] } )
      end
    end
  end # Wrap
end

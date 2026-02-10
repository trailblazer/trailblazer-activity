require "test_helper"

class CircuitProcessorTest < Minitest::Spec
  it "what" do
    # 1a. Runner that calls instance method instantly
    # 1b. no explicit termini tasks
    # 2. use signal for value transport?

    class Runner
      def self.call(task, ctx, flow_options, circuit_options)
        # task.(ctx, flow_options, circuit_options, **ctx.to_h)
        ctx[:circuit_exec_context].send(task, ctx, flow_options, circuit_options, **ctx.to_h)
      end
    end

    class Step < Struct.new(:circuit, :public_variables, :filter, :write_name)
      def call(ctx, flow_options, circuit_options) # called from tw
        Trailblazer::Activity::Pipeline.(circuit, ctx, flow_options, circuit_options.merge(runner: Runner))
      end
    end

    class VariableOnAggregate < Step
      def init_aggregate(ctx, flow_options, _, **)
        ctx[:aggregate] = {}

        return ctx, flow_options
      end

      def run_user_filter(ctx, flow_options, circuit_options, application_ctx:, **)
        value = filter.(application_ctx, **application_ctx.to_h)

        ctx[:value] = value

        return ctx, flow_options # FIXME: signal
      end

      def add_variable_to_aggregate(ctx, flow_options, circuit_options, aggregate:, value:, **)
        aggregate[write_name] = value # FIME

        return ctx, flow_options # FIXME: signal
      end

      def create_context(ctx, flow_options, _, **)
        new_ctx = Trailblazer::Context(ctx) # this is the pendant to creating a {lib_ctx}.

        return new_ctx, flow_options
      end

      def decompose_context(ctx, flow_options, circuit_options, **)
        original, mutable = ctx.decompose

        new_variables = mutable.slice(*public_variables)

        new_ctx = original.merge(new_variables)

        return new_ctx, flow_options
      end

    end

    my_user_filter = ->(ctx, params:, **) { params[:current_user] }

    sequence = [
      # [11, method(:init_aggregate)],
      [1, :run_user_filter],
      [2, :add_variable_to_aggregate],
    ]

    # apply "scoping" steps, only needed for Input/Output?
    sequence = [[0, :create_context], [11, :init_aggregate]] + sequence + [[99, :decompose_context]]
    sequence = sequence.to_h
    pp sequence


    # separation of process/ablauf logic and runtime data.
    step = Step.new(sequence, [:aggregate], filter: my_user_filter, write_name: :current_user)

    pp step.(
      {
        application_ctx: {
          params: {current_user: Object.new}
        },
        circuit_exec_context: step,
      },
      {},
      {exec_context: step} # DISCUSS
    )
  end
end

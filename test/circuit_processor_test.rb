require "test_helper"

class CircuitProcessorTest < Minitest::Spec
  it "what" do
    # 1a. Runner that calls instance method instantly
    # 1b. no explicit termini tasks
    # 2. use signal for value transport?

    class InstanceMethodRunner
      def self.call(task, ctx, flow_options, circuit_options)
        # task.(ctx, flow_options, circuit_options, **ctx.to_h)
        circuit_options[:exec_context].send(task, ctx, flow_options, circuit_options, **ctx.to_h)
      end
    end

    # DISCUSS: this should be representing ONE variable within an Input or Output p
    class Step < Struct.new(:circuit, :public_variables, :filter, :write_name)
      def call(ctx, flow_options, circuit_options) # called from tw
        # DISCUSS: maybe adding the exec_context could be done by the Runner/Circuit?
        Trailblazer::Activity::Pipeline.(circuit, ctx, flow_options, circuit_options.merge(runner: InstanceMethodRunner, exec_context: self))
      end
    end

    class Input < Struct.new(:public_variables, keyword_init: true)
      def init_aggregate(ctx, flow_options, _, **)
        ctx[:aggregate] = {}

        return ctx, flow_options
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

      # def call(ctx, flow_options, circuit_options) # called from tw.
      #   # raise @sequence.inspect
      #   circuit = @sequence
      #   # raise "input pipe should create context and drop aggregate, for all contained steps"
      #   Trailblazer::Activity::Pipeline.(circuit, ctx, flow_options, circuit_options.merge(runner: InstanceMethodRunner, exec_context: self)) # FIXME: copied from {Step#call}.
      # end
    end

    # DISCUSS: call me FilterStep
    class VariableOnAggregate < Step

      def run_user_filter(ctx, flow_options, circuit_options, application_ctx:, **)
        value = filter.(application_ctx, **application_ctx.to_h)

        ctx[:value] = value

        return ctx, flow_options # FIXME: signal
      end

      def add_variable_to_aggregate(ctx, flow_options, circuit_options, aggregate:, value:, **)
        aggregate[write_name] = value # FIME

        return ctx, flow_options # FIXME: signal
      end


    end

    my_user_filter = ->(ctx, params:, **) { params[:current_user] }

    sequence = [
      # [11, method(:init_aggregate)],
      [1, :run_user_filter],
      [2, :add_variable_to_aggregate],
    ]
    # separation of process/ablauf logic and runtime data.
    step = VariableOnAggregate.new(sequence, [:aggregate], my_user_filter, :current_user)

    # apply "scoping" steps, only needed for Input/Output?
    input_pipe = Input.new(public_variables: [:aggregate])

    input_sequence = [
      [0, input_pipe.method(:create_context)],
      [11, input_pipe.method(:init_aggregate)],
      [111, step],
      [99, input_pipe.method(:decompose_context)],
    ]

    input_pipeline = Trailblazer::Activity.Pipeline(input_sequence.to_h)



    pp input_pipeline.(
      {
        application_ctx: {
          params: {current_user: Object.new}
        },
        application_circuit_options: {exec_context: 'Operation'}
      },
      {stack: []},
      {} # exec_context is added in Step#call.
    )
  end
end

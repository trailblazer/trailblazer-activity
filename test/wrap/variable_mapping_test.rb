require "test_helper"

# Test input- and output filter for specific tasks.
# These are task wrap steps added before and after the task.
class VariableMappingTest < Minitest::Spec
  # first task
  Model = ->((ctx, flow), **) do
    ctx[:seq]            = ctx[:seq] + ["model"] # rename to model.a
    ctx[:model_nonsense] = true # filter me out

    [Activity::Right, [ctx, flow]]
  end

  # second task
  Uuid = ->((ctx, flow), **) do
    ctx[:seq] = ctx[:seq] + ["uuid"] # rename to uuid.a
    ctx[:uuid_nonsense] = false # filter me out

    [Activity::Right, [ctx, flow]]
  end

  C = ->((ctx, flow), **) do
    ctx[:c] = ctx[:a] # .dup

    [Activity::Right, [ctx, flow]]
  end

  let(:nested) do
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :C)],
        Inter::TaskRef(:C) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      ["Start.default"] # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :C => Schema::Implementation::Task(c = C, [Activity::Output(Activity::Right, :success)],                                        []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  def activity_for(model_extensions: [], uuid_extensions: [], model_task: Model)
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :Model)],
        Inter::TaskRef(:Model) => [Inter::Out(:success, :Nested)],
        Inter::TaskRef(:Nested) => [Inter::Out(:success, :Uuid)],
        Inter::TaskRef(:Uuid) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      ["Start.default"] # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)], []),
      :Model => Schema::Implementation::Task(model_task, [Activity::Output(Activity::Right, :success)], model_extensions),
      :Nested => Schema::Implementation::Task(c = nested, [Activity::Output(implementing::Success, :success)], []),
      :Uuid => Schema::Implementation::Task(d = Uuid, [Activity::Output(Activity::Right, :success)], uuid_extensions),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  let(:activity) do
    activity_for
  end

  let(:model_io) do
    # a => a+1
    input = ->((original_ctx, _flow_options), **_circuit_options) {
      Trailblazer.Context(seq: original_ctx[:seq] + [:model_in])
    }
    # a -> model.a
    output = ->(new_ctx, (original_ctx, _flow_options), **_circuit_options) {
      _, mutable_data = new_ctx.decompose

      seq = mutable_data[:seq] + [:model_out]

      original_ctx.merge(seq_from_model: seq)
    } # return the "total" ctx

    [input, output]
  end

  let(:uuid_io) do
    # a => a*3, model.a => model.a
    input   = ->((original_ctx, _flow_options), _circuit_options) { Trailblazer.Context(seq: original_ctx[:seq_from_model] + [:uuid_in]) }
    output  = ->(new_ctx, (original_ctx, _flow_options), **_circuit_options) {
      _, mutable_data = new_ctx.decompose

      seq = mutable_data[:seq] + [:uuid_out]

      original_ctx.merge({seq_from_uuid: seq})
    }

    [input, output]
  end

  # this method used to sit in {TaskWrap::VariableMapping}.
  def VariableMappingExtension(input, output, id: input.object_id, **options)
    Trailblazer::Activity::TaskWrap::Extension(
      merge: Trailblazer::Activity::TaskWrap::VariableMapping.merge_instructions_for(input, output, id: id, **options),
    )
  end

  describe "pure Input/Output" do
    it "added via {wrap_static}, manually" do
      model_input, model_output = model_io
      uuid_input, uuid_output   = uuid_io

      activity = activity_for(
        model_extensions: [VariableMappingExtension(model_input, model_output)],
        uuid_extensions: [VariableMappingExtension(uuid_input, uuid_output)]
      )

      signal, (ctx, _) = Activity::TaskWrap.invoke(
        activity,
        [
          {seq: []}.freeze, {}
        ]
      )

      expect(signal).must_equal activity.to_h[:outputs][0].signal
      expect(ctx).must_equal({:seq => [], :seq_from_model => [:model_in, "model", :model_out], :c => nil, :seq_from_uuid => [:model_in, "model", :model_out, :uuid_in, "uuid", :uuid_out]})
    end

    # DISCUSS:  if you see this and feel like it's a great idea, consider that you might
    #           not need it. Rather use the new API to add composable In() and Out() filters.
    it "allows adding multiple I/Os" do
      model_input, model_output = model_io
      uuid_input, uuid_output   = uuid_io

      model_input_2  = ->((original_ctx, _flow_options), **_circuit_options) {
       Trailblazer.Context(seq: original_ctx[:seq] + [:model_in_2])
      }

      model_output_2 = ->(new_ctx, (original_ctx, _flow_options), **_circuit_options) {
        _, mutable_data = new_ctx.decompose

        seq = mutable_data[:seq_from_model] + [:model_out_2]

        original_ctx.merge(seq_from_model: seq)
      }

      activity = activity_for(
        model_extensions: [
          VariableMappingExtension(model_input_2, model_output_2),
          VariableMappingExtension(model_input, model_output, input_id: "task_wrap.input.2", output_id: "task_wrap.output.2")
        ],
        uuid_extensions: [VariableMappingExtension(uuid_input, uuid_output)]
      )

      signal, (ctx, _) = Activity::TaskWrap.invoke(
        activity,
        [
          {seq: []}.freeze, {}
        ]
      )

      expect(signal).must_equal activity.to_h[:outputs][0].signal
      expect(ctx).must_equal({:seq => [], :seq_from_model => [:model_in_2, :model_in, "model", :model_out, :model_out_2], :c => nil, :seq_from_uuid => [:model_in_2, :model_in, "model", :model_out, :model_out_2, :uuid_in, "uuid", :uuid_out]})
    end

    it "added via {:wrap_runtime}" do
      model_input, model_output = model_io
      uuid_input, uuid_output   = uuid_io

      runtime = {}

      # add filters around Model.
      merge = [
        {insert: [Trailblazer::Activity::Adds::Insert.method(:Prepend), "task_wrap.call_task"],  row: TaskWrap::Pipeline::Row["task_wrap.input", TaskWrap::Input.new(model_input, id: 1)]},
        {insert: [Trailblazer::Activity::Adds::Insert.method(:Append), "task_wrap.call_task"],   row: TaskWrap::Pipeline::Row["task_wrap.output", TaskWrap::Output.new(model_output, id: 1)]}
      ]

      runtime[Model] = TaskWrap::Pipeline::Merge.new(*merge)

      # add filters around Uuid.
      merge = [
        {insert: [Trailblazer::Activity::Adds::Insert.method(:Prepend), "task_wrap.call_task"],  row: TaskWrap::Pipeline::Row["task_wrap.input", TaskWrap::Input.new(uuid_input, id: 1)]},
        {insert: [Trailblazer::Activity::Adds::Insert.method(:Append), "task_wrap.call_task"],   row: TaskWrap::Pipeline::Row["task_wrap.output", TaskWrap::Output.new(uuid_output, id: 1)]}
      ]

      runtime[Uuid] = TaskWrap::Pipeline::Merge.new(*merge)

      signal, (options, _) = Activity::TaskWrap.invoke(
        activity,
        [
          options = {seq: []}.freeze,
          {}
        ],
        wrap_runtime: runtime
      ) # dynamic additions from the outside (e.g. tracing), also per task.

      expect(signal).must_equal activity.to_h[:outputs][0].signal
      expect(options).must_equal({:seq => [], :seq_from_model => [:model_in, "model", :model_out], :c => nil, :seq_from_uuid => [:model_in, "model", :model_out, :uuid_in, "uuid", :uuid_out]})
    end

    it "passes through {flow_options} and {circuit_options} to both filters" do
      model_input_2  = ->((original_ctx, flow_options), **circuit_options) { Trailblazer.Context(seq: original_ctx[:seq] + [:model_in_2], input_flow_options: flow_options, input_circuit_options: circuit_options.keys) }
      model_output_2 = ->(new_ctx, (original_ctx, flow_options), **circuit_options) {
        original, = new_ctx.decompose

        original_ctx.merge(original).merge(output_flow_options: flow_options, output_circuit_options: circuit_options.keys)
      }

      activity = activity_for(
        model_extensions: [
          VariableMappingExtension(model_input_2, model_output_2)
        ]
      )

      signal, (ctx, _) = Activity::TaskWrap.invoke(
        activity,
        [
          {seq: []}.freeze, {yo: 1}
        ]
      )

      expect(signal).must_equal activity.to_h[:outputs][0].signal
      expect(ctx).must_equal({:seq => [:model_in_2, "uuid"], :input_flow_options => {:yo => 1}, :input_circuit_options => %i[wrap_runtime activity runner], :output_flow_options => {:yo => 1}, :output_circuit_options => %i[wrap_runtime activity runner], :c => nil, :uuid_nonsense => false})
    end

    it "uses and returns correct {flow_options}" do
      lets_change_flow_options = ->((ctx, flow_options), circuit_options) do
        ctx[:seq] << :lets_change_flow_options

      # allows to change flow_options in the task.
        flow_options = flow_options.merge(coffee: true)

        [Trailblazer::Activity::Right, [ctx, flow_options]]
      end

      model_input  = ->((original_ctx, _flow_options), **_circuit_options) { Trailblazer.Context(seq: original_ctx[:seq] + [:model_input]) }
      model_output = ->(new_ctx, (original_ctx, _flow_options), **_circuit_options) { original, _ = new_ctx.decompose; original }

      activity = activity_for(
        model_task: lets_change_flow_options,
        model_extensions: [VariableMappingExtension(model_input, model_output)],
      )

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(
        activity,
        [
          {seq: []}, {yo: 1}
        ]
      )

      _(ctx.inspect).must_equal %{{:seq=>[:model_input, :lets_change_flow_options, \"uuid\"], :c=>nil, :uuid_nonsense=>false}}
      _(flow_options.inspect).must_equal %{{:yo=>1, :coffee=>true}}
    end
  end

  describe "Input/Output with scope" do
    it do
      skip

      model_input  = ->(options) { {:a       => options[:a] + 1} }
      model_output = ->(options) { {:model_a => options[:a]} }
      uuid_input   = ->(options) { {:a       => options[:a] * 3, :model_a => options[:model_a]} }
      uuid_output  = ->(options) { {:uuid_a  => options[:a]} }

      runtime = {}

      # add filters around Model.
      runtime[ Model ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new(Activity::TaskWrap::Input::Scoped.new(Trailblazer::Option(model_input))), id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new(Activity::TaskWrap::Output::Unscoped.new(Trailblazer::Option(model_output))), id: "task_wrap.output", before: "End.success", group: :end
      end

      # add filters around Uuid.
      runtime[ Uuid ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new(Activity::TaskWrap::Input::Scoped.new(Trailblazer::Option(uuid_input))), id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new(Activity::TaskWrap::Output::Unscoped.new(Trailblazer::Option(uuid_output))), id: "task_wrap.output", before: "End.success", group: :end
      end

      signal, (options, _) = Activity::TaskWrap.invoke(
        activity,
        [
          options = {:a => 1},
          {}
        ],
        wrap_runtime: runtime
      ) # dynamic additions from the outside (e.g. tracing), also per task.

      expect(signal).must_equal activity.outputs[:success].signal
      expect(options).must_equal({:a => 1, :model_a => 4, :c => 1, :uuid_a => 7})
    end
  end
end

# step Tyrant::Signup, #scope: :auth
#   input do
#     field :email, EmailAddress
#   end
#   output do
#     field :auth, Tyrant::Auth
#   end

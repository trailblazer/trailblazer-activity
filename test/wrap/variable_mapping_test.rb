require "test_helper"

# Test input- and output filter for specific tasks.
# These are task wrap steps added before and after the task.
class VariableMappingTest < Minitest::Spec
  # first task
  Model = ->((options, flow), **o) do
    options[:a]        = options[:a] * 2 # rename to model.a
    options[:model_nonsense] = true       # filter me out

    [Activity::Right, [options, flow]]
  end

  # second task
  Uuid = ->((options, flow), **o) do
    options[:a]             = options[:a] + options[:model_a] # rename to uuid.a
    options[:uuid_nonsense] = false                             # filter me out

    [Activity::Right, [options, flow]]
  end

  C = ->((ctx, flow), **) do
    ctx[:c] = ctx[:a]#.dup

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
      ["Start.default"], # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :C => Schema::Implementation::Task(c = C, [Activity::Output(Activity::Right, :success)],                                        []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  def activity_for(model_extensions: [], uuid_extensions: [])
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :Model)],
        Inter::TaskRef(:Model)  => [Inter::Out(:success, :Nested)],
        Inter::TaskRef(:Nested) => [Inter::Out(:success, :Uuid)],
        Inter::TaskRef(:Uuid)   => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      ["Start.default"], # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],  []),
      :Model          => Schema::Implementation::Task(b = Model, [Activity::Output(Activity::Right, :success)],                 model_extensions),
      :Nested         => Schema::Implementation::Task(c = nested, [Activity::Output(implementing::Success, :success)],          []),
      :Uuid           => Schema::Implementation::Task(d = Uuid, [Activity::Output(Activity::Right, :success)],                  uuid_extensions),
      "End.success"   => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  let (:activity) do
    activity_for()
  end

  let(:model_io) do
      # a => a+1
    input  = ->(original_ctx) { new_ctx = Trailblazer.Context({ :a       => original_ctx[:a]+1 }) } # a = 2   # DISCUSS: how do we access, say. model.class from a container now?
      # a -> model.a
    output = ->(original_ctx, new_ctx) {
      _, mutable_data = new_ctx.decompose

      # "strategy" and user block
      original_ctx.merge(:model_a => mutable_data[:a])
    } # return the "total" ctx

    [input, output]
  end

  let(:uuid_io) do
      # a => a*3, model.a => model.a
    input   = ->(original_ctx) { new_ctx = Trailblazer.Context({ :a       => original_ctx[:a]*3, :model_a => original_ctx[:model_a] }) }
    output  = ->(original_ctx, new_ctx) {
      _, mutable_data = new_ctx.decompose

      # "strategy" and user block
      original_ctx.merge({ :uuid_a  => mutable_data[:a] })
    }

    [input, output]
  end

  describe "pure Input/Output" do
    it "added via {wrap_static}, manually" do
      model_input, model_output = model_io
      uuid_input, uuid_output   = uuid_io

      activity = activity_for(
        model_extensions: [Activity::TaskWrap::VariableMapping::Extension(Model, model_input, model_output)],
        uuid_extensions: [Activity::TaskWrap::VariableMapping::Extension(Uuid, uuid_input, uuid_output)],
      )

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 }.freeze,
          {},
        ],
      )

      signal.must_equal activity.to_h[:outputs][0].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 7 })
    end

    it "added via {wrap_runtime}" do
      model_input, model_output = model_io
      uuid_input, uuid_output   = uuid_io

      runtime = {}

      # add filters around Model.
      merge = [
        [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["task_wrap.input", TaskWrap::Input.new( Trailblazer::Option(model_input) )]],
        [TaskWrap::Pipeline.method(:append),  nil, ["task_wrap.output", TaskWrap::Output.new( Trailblazer::Option(model_output) )]],
      ]

      runtime[ Model ] = TaskWrap::Pipeline::Merge.new(*merge)

      # add filters around Uuid.
      merge = [
        [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["task_wrap.input", TaskWrap::Input.new( Trailblazer::Option(uuid_input) )]],
        [TaskWrap::Pipeline.method(:append),  nil, ["task_wrap.output", TaskWrap::Output.new( Trailblazer::Option(uuid_output) )]],
      ]

      runtime[ Uuid ] = TaskWrap::Pipeline::Merge.new(*merge)

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 }.freeze,
          {},
        ],

        wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.to_h[:outputs][0].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 7 })
    end
  end






  describe "Default injection" do
    let(:macro) do
       Module.new do
        def self.model((ctx, flow_options), *)
          ctx[:model] = ctx[:model_class].new

          return Activity::Right, [ctx, flow_options]
        end
      end
    end

    def activity_for(a:, b:, a_extensions:, b_extensions:)
      intermediate = Inter.new(
        {
          Inter::TaskRef("Model_a")                       => [Inter::Out(:success, "capture_a")],
          Inter::TaskRef("capture_a")                     => [Inter::Out(:success, "Model_b")],
          # Inter::TaskRef(:Nested)                       => [Inter::Out(:success, :Uuid)],
          Inter::TaskRef("Model_b")                       => [Inter::Out(:success, "End.success")],
          Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
        },
        ["End.success"],
        ["Model_a"], # start
      )




# todo: make this TaskWrap::Defaulter




      capture_a = ->((ctx, flow_options), *) do
        ctx[:capture_a] = ctx.inspect
        return Activity::Right, [ctx, flow_options]
      end

      implementation = {
        "Model_a"       => Schema::Implementation::Task(a,    [Activity::Output(Activity::Right, :success)],       a_extensions),
        # :Nested         => Schema::Implementation::Task(nested, [Activity::Output(implementing::Success, :success)],                  []),
        "Model_b"       => Schema::Implementation::Task(b, [Activity::Output(Activity::Right, :success)],                        b_extensions),
        "End.success"   => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)], []),

        "capture_a"     => Schema::Implementation::Task(capture_a, [Activity::Output(Activity::Right, :success)],                  []),
      }

      schema = Inter.(intermediate, implementation)

      Activity.new(schema)
    end

    def Model_defaults(default_class)
      input  = ->(original_ctx) { new_ctx = Trailblazer.Context(model_class: original_ctx[:model_class] || default_class) }  # NOTE how we, so far, don't pass anything of original_ctx here.
      output = ->(original_ctx, new_ctx) {
        _, mutable_data = new_ctx.decompose

        # we are only interested in the {mutable_data} part since the disposed part is the {:input}.
        original_ctx.merge(mutable_data)
      }

      return input, output
    end

    # Two identical macros with different defaults, but no output mapping.
    it "calls both {Model()} macros correctly, but overrides {a} value of {:model} with {b}'s" do
      a = macro.method(:model)
      b = ->(*args) { macro.model(*args) }

      activity = activity_for(a: a, b: b,
        a_extensions: [TaskWrap::VariableMapping::Extension(a, *Model_defaults(Array))],
        b_extensions: [TaskWrap::VariableMapping::Extension(b, *Model_defaults(Hash ))],

      )

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [{}.freeze, {}])

      signal.must_equal activity.to_h[:outputs][0].signal
      ctx.inspect.must_equal %{{:model=>{}, :capture_a=>\"{:model=>[]}\"}}
    end
  end







  describe "Input/Output with scope" do
    it do
      skip

      model_input  = ->(options) { { :a       => options[:a]+1 } }
      model_output = ->(options) { { :model_a => options[:a] } }
      uuid_input   = ->(options) { { :a       => options[:a]*3, :model_a => options[:model_a] } }
      uuid_output  = ->(options) { { :uuid_a  => options[:a] } }

      runtime = {}

      # add filters around Model.
      runtime[ Model ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new(Activity::TaskWrap::Input::Scoped.new( Trailblazer::Option(model_input) )),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new(Activity::TaskWrap::Output::Unscoped.new( Trailblazer::Option(model_output) )), id: "task_wrap.output", before: "End.success", group: :end
      end

      # add filters around Uuid.
      runtime[ Uuid ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new(Activity::TaskWrap::Input::Scoped.new( Trailblazer::Option(uuid_input) )),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new(Activity::TaskWrap::Output::Unscoped.new( Trailblazer::Option(uuid_output) )), id: "task_wrap.output", before: "End.success", group: :end
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 },
          {},
        ],

        wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 7 })
    end
  end

  # describe "Input/Output with mapping DSL" do
  #   it do

  #     model_input  = [:a]# ->(options) { { :a       => options[:a]+1 } }
  #     model_output = { :a=>:model_a } # ->(options) { { :model_a => options[:a] } }
  #     uuid_input   = [:a, :model_a]# ->(options) { { :a       => options[:a]*3, :model_a => options[:model_a] } }
  #     uuid_output  = { :a=>:uuid_a }#->(options) { { :uuid_a  => options[:a] } }

  #     runtime = {}

  #     # add filters around Model.
  #     runtime[ Model ] = Module.new do
  #       extend Activity::Path::Plan()

  #       task Activity::TaskWrap::Input::FromDSL( model_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
  #       task Activity::TaskWrap::Output::FromDSL( model_output ), id: "task_wrap.output", before: "End.success", group: :end
  #     end

  #     # add filters around Uuid.
  #     runtime[ Uuid ] = Module.new do
  #       extend Activity::Path::Plan()

  #       task Activity::TaskWrap::Input::FromDSL( uuid_input ),   id: "task_wrap.input", before: "task_wrap.call_task"
  #       task Activity::TaskWrap::Output::FromDSL( uuid_output ), id: "task_wrap.output", before: "End.success", group: :end
  #     end

  #     signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
  #       [
  #         options = { :a => 1 },
  #         {},
  #       ],

  #       wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
  #     )

  #     signal.must_equal activity.outputs[:success].signal
  #     options.must_equal({:a=>1, :model_a=>2, :c=>1, :uuid_a => 3 })
  #   end
  # end

  describe "Input/Output via VariableMapping DSL" do
    it "allows hash and array" do
      skip

      _nested = nested

      activity = Module.new do
        extend Activity::Path()

        task task: Model, Trailblazer::Activity::TaskWrap::VariableMapping(
          input:  [:a],
          output: { :a=>:model_a }
        ) => true
        task task: _nested, _nested.outputs[:success] => Track(:success)
        task task: Uuid, Trailblazer::Activity::TaskWrap::VariableMapping(
          input:  [:a, :model_a],
          output: { :a=>:uuid_a }
        ) => true
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 },
          {},
        ],
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>2, :c=>1, :uuid_a => 3 })
    end

    it "allows procs with kwargs" do
      skip "lower api"

      _nested = nested

      activity = Module.new do
        extend Activity::Path()

        task task: Model, Trailblazer::Activity::TaskWrap::VariableMapping(
          input:  ->(ctx, a:, **) { { :a => a+1 } },
          output: ->(ctx, a:, **) { { :model_a=>a } }
        ) => true
        task task: _nested, _nested.outputs[:success] => Track(:success)
        task task: Uuid, Trailblazer::Activity::TaskWrap::VariableMapping(
          input:  ->(ctx, a:, **) { { :a => a, :model_a => ctx[:model_a] } },
          output: ->(ctx, a:, **) { { :uuid_a=>a } }
        ) => true
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 },
          {},
        ],
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a=>5 })
    end
  end

  describe "via DSL" do
    it "allows array and hash" do
      skip "move me to DSL"

      _nested = nested

      activity = Module.new do
        extend Activity::Path()

        # a => a, ctx[:model].id => id
        task task: Model,     input: [:a], output: { :a=>:model_a }
        task task: _nested,    _nested.outputs[:success] => Track(:success)
        task task: Uuid,      input: [:a, :model_a], output: { :a=>:uuid_a }
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 },
          {},
        ],
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>2, :c=>1, :uuid_a => 3 })
    end

    it "allows procs, too" do
      skip "move me to DSL"

      _nested = nested

      activity = Module.new do
        extend Activity::Path()

        # a => a, ctx[:model].id => id
        task task: Model,     input: ->(ctx, a:, **) { { :a => a+1 } }, output: ->(ctx, a:, **) { { model_a: a } }
        task task: _nested,    _nested.outputs[:success] => Track(:success)
        task task: Uuid,      input: [:a, :model_a], output: { :a=>:uuid_a }
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 },
          {},
        ],
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 5 })
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

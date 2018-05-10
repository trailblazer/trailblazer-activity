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
    Module.new do
      extend Activity::Path()

      task task: C
    end
  end

  let (:activity) do
    _nested = nested

    Module.new do
      extend Activity::Path()

      task task: Model
      task task: _nested, _nested.outputs[:success] => Track(:success)
      task task: Uuid
    end
  end

  describe "pure Input/Output" do
    it do
        # a => a+1
      model_input  = ->(original_ctx) { new_ctx = Trailblazer.Context({ :a       => original_ctx[:a]+1 }) } # a = 2   # DISCUSS: how do we access, say. model.class from a container now?
        # a -> model.a
      model_output = ->(original_ctx, new_ctx) {
        _, mutable_data = new_ctx.decompose

        # "strategy" and user block
        original_ctx.merge(:model_a => mutable_data[:a])
      } # return the "total" ctx

        # a => a*3, model.a => model.a
      uuid_input   = ->(original_ctx) { new_ctx = Trailblazer.Context({ :a       => original_ctx[:a]*3, :model_a => original_ctx[:model_a] }) }
      uuid_output  = ->(original_ctx, new_ctx) {
        _, mutable_data = new_ctx.decompose

        # "strategy" and user block
        original_ctx.merge({ :uuid_a  => mutable_data[:a] })
      }

      runtime = {}

      # add filters around Model.
      runtime[ Model ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( Trailblazer::Option(model_input) ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( Trailblazer::Option(model_output) ), id: "task_wrap.output", before: "End.success", group: :end
      end

      # add filters around Uuid.
      runtime[ Uuid ] = Module.new do
        extend Activity::Path::Plan()

        task Activity::TaskWrap::Input.new( Trailblazer::Option(uuid_input) ),   id: "task_wrap.input", before: "task_wrap.call_task"
        task Activity::TaskWrap::Output.new( Trailblazer::Option(uuid_output) ), id: "task_wrap.output", before: "End.success", group: :end
      end

      signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
        [
          options = { :a => 1 }.freeze,
          {},
        ],

        wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.outputs[:success].signal
      options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 7 })
    end
  end

  describe "Input/Output with scope" do
    it do

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

require "test_helper"

# Test input- and output filter for specific tasks.
# These are task wrap steps added before and after the task.
class VariableMappingTest < Minitest::Spec
  # first task
  Model = ->((options, flow), **o) do
    options["a"]        = options["a"] * 2 # rename to model.a
    options["model.nonsense"] = true       # filter me out

    [Circuit::Right, [options, flow]]
  end

  # second task
  Uuid = ->((options, flow), **o) do
    options["a"]             = options["a"] + options["model.a"] # rename to uuid.a
    options["uuid.nonsense"] = false                             # filter me out

    [Circuit::Right, [options, flow]]
  end

  let (:activity) do
    Activity.from_hash do |start, _end|
      {
        start     => { Circuit::Right => Model },
        Model     => { Circuit::Right => Uuid  },
        Uuid      => { Circuit::Right => _end }
      }
    end
  end

  describe "input/output" do
    let(:model_input)  { ->(options) { { "a"       => options["a"]+1 } }  }
    let(:model_output) { ->(options) { { "model.a" => options["a"] } } }
    let(:uuid_input)   { ->(options) { { "a"       => options["a"]*3, "model.a" => options["model.a"] } }  }
    let(:uuid_output)  { ->(options) { { "uuid.a"  => options["a"] } } }

    it do
      runtime = Hash.new([])

      # add filters around Model.
      runtime[ Model ] = [
        [ :insert_before!, "task_wrap.call_task", node: [ Activity::Wrap::Input.new( model_input ),   { id: "task_wrap.input" } ],  outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        [ :insert_before!, "End.default",         node: [ Activity::Wrap::Output.new( model_output ), { id: "task_wrap.output" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
      ]

      # add filters around Uuid.
      runtime[ Uuid ] = [
        [ :insert_before!, "task_wrap.call_task", node: [ Activity::Wrap::Input.new( uuid_input ),   { id: "task_wrap.input" } ],  outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        [ :insert_before!, "End.default",         node: [ Activity::Wrap::Output.new( uuid_output ), { id: "task_wrap.output" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
      ]

      signal, (options, flow_options) = activity.(
      [
        options = { "a" => 1 },
        {},
      ],

      wrap_runtime: runtime, # dynamic additions from the outside (e.g. tracing), also per task.
      runner: Activity::Wrap::Runner,
      wrap_static: Hash.new( Activity::Wrap.initial_activity ), # per activity?
    )

    signal.must_equal activity.outputs.keys.first # the actual activity's End signal.
    options.must_equal({"a"=>1, "model.a"=>4, "uuid.a" => 7 })
    end
  end
end

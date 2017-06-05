require "test_helper"
require "trailblazer/circuit/trace"
require "trailblazer/circuit/wrapped"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  SpecialDirection = Class.new
  Wrapped = Circuit::Activity::Wrapped

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }
  Save  = ->(direction, options, flow_options) { options["saved"]=true;   [direction, options, flow_options] }
  Upload   = ->(direction, options, flow_options) { options["bits"]=64;   [direction, options, flow_options] }
  Cleanup  = ->(direction, options, flow_options) { options["ok"]=true;   [direction, options, flow_options] }

  MyInject = ->(direction, options, flow_options) { [direction, options.merge( current_user: Module ), flow_options] }

  #- tracing
  let (:with_tracing) do
    model_pipe = Circuit::Activity::Before( Wrapped::Activity, Wrapped::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right )
    model_pipe = Circuit::Activity::Before( model_pipe, Wrapped::Activity[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right )
  end

  describe "nested trailing" do
    let (:more_nested) do
      Circuit::Activity(id: "more_nested", Upload=>"more_nested.Upload") do |act|
        {
          act[:Start] => { Circuit::Right => Upload },
          Upload        => { Circuit::Right => act[:End] }
        }
      end
    end

    let (:nested) do
      Circuit::Activity(id: "nested") do |act|
        {
          act[:Start] => { Circuit::Right    => Save },
          Save        => { Circuit::Right    => __nested = Circuit::Nested(more_nested) },
          __nested    => { more_nested[:End] => Cleanup },
          Cleanup     => { Circuit::Right => act[:End] }
        }
      end
    end

    let (:activity) do
      Circuit::Activity(id: "outsideg", Model=>"outsideg.Model", Uuid=>"outsideg.Uuid") do |act|
        {
          act[:Start] => { Circuit::Right => Model },
          Model       => { Circuit::Right => __nested = Circuit::Nested( nested ) },
          __nested    => { nested[:End] => Uuid },
          Uuid        => { SpecialDirection => act[:End] }
        }
      end
    end

    it "trail" do
      step_runners = {
        nil   => with_tracing,
      }

      direction, options, flow_options = activity.(
        activity[:Start],
        options = {},
        { runner: Wrapped::Runner, stack: Circuit::Trace::Stack.new, step_runners: step_runners, debug: activity.circuit.instance_variable_get(:@name) })

      direction.must_equal activity[:End] # the actual activity's End signal.
      options  .must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})

      # unit tests, 2BRM
      # flow_options[:stack].to_a[2][0].last.must_equal({:id=>"outsideg"})
      # flow_options[:stack].to_a[2][1].first.last.must_equal({:id=>"nested"})
      # flow_options[:stack].to_a[3][0].last.must_equal({:id=>"outsideg"})





      require "trailblazer/circuit/present"

      puts tree = Circuit::Trace::Present.tree(flow_options[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- outsideg.Model
|-- #<Trailblazer::Circuit::Nested:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:.rb:12 (lambda)>
|   |-- #<Trailblazer::Circuit::Nested:>
|   |   |-- #<Trailblazer::Circuit::Start:>
|   |   |-- more_nested.Upload
|   |   |-- #<Trailblazer::Circuit::End:>
|   |   `-- #<Trailblazer::Circuit::Nested:>
|   |-- #<Proc:.rb:14 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Circuit::Nested:>
|-- outsideg.Uuid
`-- #<Trailblazer::Circuit::End:>}
    end
  end
end

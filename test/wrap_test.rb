require "test_helper"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  SpecialDirection = Class.new
  Wrap             = Circuit::Wrap

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }
  Save  = ->(direction, options, flow_options) { options["saved"]=true;   [direction, options, flow_options] }
  Upload   = ->(direction, options, flow_options) { options["bits"]=64;   [direction, options, flow_options] }
  Cleanup  = ->(direction, options, flow_options) { options["ok"]=true;   [direction, options, flow_options] }

  MyInject = ->(direction, options, flow_options) { [direction, options.merge( current_user: Module ), flow_options] }

  #- tracing
  let (:with_tracing) do
    model_pipe = Circuit::Activity::Before( Wrap::Activity, Wrap::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right )
    model_pipe = Circuit::Activity::Before( model_pipe, Wrap::Activity[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right )
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
      wrap_alterations = [
        ->(wrap_circuit) do
          wrap_circuit = Circuit::Activity::Before( wrap_circuit, Wrap::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right )
          wrap_circuit = Circuit::Activity::Before( wrap_circuit, Wrap::Activity[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right )
        end
      ]



      # in __call__, we now need to merge the step's wrap with the alterations.
      # def __call__(start_at, options, flow_options)
      #   # merge dynamic runtime part (e.g. tracing) with the static wrap
      #   # DISCUSS: now, the operation knows about those wraps, we should shift that to the Wrap::Runner.
      #   wrap_alterations = flow_options[:wrap_alterations]
      #   task_wraps = self["__task_wraps__"].collect { |task, wrap_circuit| [ task, wrap_alterations[nil].(wrap_circuit) ] }.to_h
      #   activity   = self["__activity__"]


      #   activity.(start_at, options, flow_options.merge(
      #     exec_context: new,
      #     task_wraps:   task_wraps,
      #     debug:        activity.circuit.instance_variable_get(:@name) ))


      #   # task_wraps: wraps
      #   # debug: activity.circuit.instance_variable_get(:@name)
      # end

      # # Trace.call
      # __call__( self["__activity__"][:Start], options, { runner: Wrap::Runner, wrap_alterations: wrap_alterations } )


      direction, options, flow_options = activity.(
        activity[:Start],
        options = {},
        {

          # Wrap::Runner specific:
          runner:           Wrap::Runner,
          task_wraps:       Wrap::Wraps.new(Wrap::Activity),      # wrap per task of the activity.
          wrap_alterations: Wrap::Alterations.new(wrap_alterations), # dynamic additions from the outside (e.g. tracing), also per task.

          # Trace specific:
          stack:      Circuit::Trace::Stack.new,
          debug:      activity.circuit.instance_variable_get(:@name) # optional, eg. per Activity.
        }
      )

      direction.must_equal activity[:End] # the actual activity's End signal.
      options  .must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})


      puts tree = Circuit::Trace::Present.tree(flow_options[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- outsideg.Model
|-- #<Trailblazer::Circuit::Nested:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:.rb:10 (lambda)>
|   |-- #<Trailblazer::Circuit::Nested:>
|   |   |-- #<Trailblazer::Circuit::Start:>
|   |   |-- #<Proc:.rb:11 (lambda)>
|   |   |-- #<Trailblazer::Circuit::End:>
|   |   `-- #<Trailblazer::Circuit::Nested:>
|   |-- #<Proc:.rb:12 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Circuit::Nested:>
|-- outsideg.Uuid
`-- #<Trailblazer::Circuit::End:>}
    end
  end
end

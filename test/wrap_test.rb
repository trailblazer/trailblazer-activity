require "test_helper"

class StepPipeTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  Activity         = Trailblazer::Activity
  SpecialDirection = Class.new
  Wrap             = Circuit::Wrap

  Model = ->(direction, options, flow_options) { options["model"]=String; [direction, options, flow_options] }
  Uuid  = ->(direction, options, flow_options) { options["uuid"]=999;     [ SpecialDirection, options, flow_options] }
  Save  = ->(direction, options, flow_options) { options["saved"]=true;   [direction, options, flow_options] }
  Upload   = ->(direction, options, flow_options) { options["bits"]=64;   [direction, options, flow_options] }
  Cleanup  = ->(direction, options, flow_options) { options["ok"]=true;   [direction, options, flow_options] }

  MyInject = ->(direction, options, flow_options) { [direction, options.merge( current_user: Module ), flow_options] }

  #- tracing

  describe "nested trailing" do
    let (:more_nested) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start => { Circuit::Right => Upload },
          Upload        => { Circuit::Right => _end }
        }
      end
    end

    let (:nested) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start => { Circuit::Right    => Save },
          Save        => { Circuit::Right    => __nested = Activity::Nested(more_nested) },
          __nested    => { more_nested.end_events.first => Cleanup },
          Cleanup     => { Circuit::Right => _end }
        }
      end
    end

    let (:activity) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start => { Circuit::Right => Model },
          Model       => { Circuit::Right => __nested = Activity::Nested( nested ) },
          __nested    => { nested.end_events.first => Uuid },
          Uuid        => { SpecialDirection => _end }
        }
      end
    end

    #---
    #-
    describe "Wrap::Runner#call with invalid input" do
      def runner(flow_options, static_wraps={}, activity=more_nested)
        direction, options, flow_options = activity.(
          nil,
          {},
          {
            runner: Wrap::Runner,
          }.merge(flow_options),
          static_wraps
        )
      end

      let(:wrap_alterations) do
        [
          [ :insert_before!, "task_wrap.call_task", node: [ Circuit::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
          [ :insert_before!, [:End, :default], node: [ Circuit::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        ]
      end

      # no :wrap_alterations, default Wrap
      it do
        assert_raises do
          direction, options, flow_options = runner( bla: "Ignored" )
        end.to_s.must_equal %{Please provide :wrap_runtime}
      end

      # specific wrap for A, default for B.
      it do
        only_for_wrap = ->(direction, options, *args) { options[:upload] ||= []; options[:upload]<<1; [ direction, options, *args ] }
        upload_wrap   = [ [ :insert_before!, "task_wrap.call_task", node: [ only_for_wrap, { id: "task_wrap.upload" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ] ]

        wrap_static         = Hash.new( Trailblazer::Circuit::Wrap.initial_activity )
        wrap_static[Upload] = Trailblazer::Activity.merge( Trailblazer::Circuit::Wrap.initial_activity, upload_wrap )

        direction, options, flow_options, *ret = runner(
          {
            wrap_runtime:  Hash.new(wrap_alterations),

            stack:         Circuit::Trace::Stack.new,
            introspection: { } # TODO: crashes without :debug.
          },
          wrap_static
        )

        # upload should contain only one 1.
        options.inspect.must_equal %{{:upload=>[1], \"bits\"=>64}}

        tree = Circuit::Trace::Present.tree(flow_options[:stack].to_a)

        # all three tasks should be executed.
        tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- #<Proc:.rb:12 (lambda)>
`-- #<Trailblazer::Circuit::End:>}
      end
    end

    #---
    #- Tracing
    it "trail" do
      wrap_alterations = [
        [ :insert_before!, "task_wrap.call_task", node: [ Circuit::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
        [ :insert_before!, [:End, :default], node: [ Circuit::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right ) },
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Activity[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right ) },
      ]

      direction, options, flow_options = activity.(
        nil,
        options = {},
        {
          # Wrap::Runner specific:
          runner:       Wrap::Runner,
          wrap_static:  Hash.new( Trailblazer::Circuit::Wrap.initial_activity ),
          wrap_runtime: Hash.new(wrap_alterations), # dynamic additions from the outside (e.g. tracing), also per task.

          # Trace specific:
          stack:      Circuit::Trace::Stack.new,
          introspection:      { Model => { id: "outsideg.Model" }, Uuid => { id: "outsideg.Uuid" } } # optional, eg. per Activity.
        }
      )

      direction.must_equal activity.end_events.first # the actual activity's End signal.
      options  .must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})


      puts tree = Circuit::Trace::Present.tree(flow_options[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- outsideg.Model
|-- #<Trailblazer::Activity::Nested:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:.rb:11 (lambda)>
|   |-- #<Trailblazer::Activity::Nested:>
|   |   |-- #<Trailblazer::Circuit::Start:>
|   |   |-- #<Proc:.rb:12 (lambda)>
|   |   |-- #<Trailblazer::Circuit::End:>
|   |   `-- #<Trailblazer::Activity::Nested:>
|   |-- #<Proc:.rb:13 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Activity::Nested:>
|-- outsideg.Uuid
`-- #<Trailblazer::Circuit::End:>}
    end
  end
end

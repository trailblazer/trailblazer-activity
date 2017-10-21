require "test_helper"

class WrapTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  Activity         = Trailblazer::Activity
  SpecialDirection = Class.new
  Wrap             = Activity::Wrap

  Model     = ->((options, *args), **circuit_options) { options = options.merge("model" => String); [ Circuit::Right, [options, *args], **circuit_options] }
  Uuid      = ->((options, *args), **circuit_options) { options = options.merge("uuid" => 999);     [ SpecialDirection, [options, *args], **circuit_options] }
  Save      = ->((options, *args), **circuit_options) { options = options.merge("saved" => true);   [ Circuit::Right, [options, *args], **circuit_options] }
  Upload    = ->((options, *args), **circuit_options) { options = options.merge("bits" => 64);      [ Circuit::Right, [options, *args], **circuit_options] }
  Cleanup   = ->((options, *args), **circuit_options) { options = options.merge("ok" => true);      [ Circuit::Right, [options, *args], **circuit_options] }

  MyInject  = ->((options)) { [ Circuit::Right, options.merge( current_user: Module ) ] }

  #- tracing

  describe "nested trailing" do
    let (:more_nested) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start  => { Circuit::Right => Upload },
          Upload => { Circuit::Right => _end }
        }
      end
    end

    let (:nested) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start => { Circuit::Right    => Save },
          Save        => { Circuit::Right  => more_nested },
          more_nested => { more_nested.end_events.first => Cleanup },
          Cleanup     => { Circuit::Right => _end }
        }
      end
    end

    let (:activity) do
      Trailblazer::Activity.from_hash do |start, _end|
        {
          start     => { Circuit::Right => Model },
          Model     => { Circuit::Right => nested  },
          nested    => { nested.end_events.first => Uuid },
          Uuid      => { SpecialDirection => _end }
        }
      end
    end

    describe "plain TaskWrap without additional steps" do
      it do
        signal, (options, flow_options) = activity.(
        [
          options = {},
          {},
        ],

        wrap_runtime: Hash.new([]), # dynamic additions from the outside (e.g. tracing), also per task.
        runner: Wrap::Runner,
        wrap_static: Hash.new( Trailblazer::Activity::Wrap.initial_activity ), # per activity?
      )

      signal.must_equal activity.end_events.first # the actual activity's End signal.
      options.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})
      end
    end

    #---
    #-
    describe "Wrap::Runner#call with :wrap_runtime" do
      let(:wrap_alterations) do
        [
          [ :insert_before!, "task_wrap.call_task", node: [ Activity::Wrap::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
          [ :insert_before!, "End.default", node: [ Activity::Wrap::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        ]
      end

      # no :wrap_alterations, default Wrap
      it "raises an exception when :wrap_runtime parameter is missing" do
        assert_raises do
          signal, *args = more_nested.( [ options = {}, { } ], runner: Wrap::Runner, wrap_static: {} )
        # end.to_s.must_equal %{Please provide :wrap_runtime}
        end.to_s.must_equal %{}
      end

      # specific wrap for A, default for B.
      it "specific wrap for A, default for B" do
        only_for_wrap = ->(( cdfg, original_args), **circuit_options) do
          _options, _ = original_args[0]
          _options[:upload] ||= []
          _options[:upload]<<1

          [ Circuit::Right, [ cdfg, original_args], circuit_options ]
        end
        upload_wrap   = [ [ :insert_before!, "task_wrap.call_task", node: [ only_for_wrap, { id: "task_wrap.upload" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ] ]

        wrap_static         = Hash.new( Trailblazer::Activity::Wrap.initial_activity )
        wrap_static[Upload] = Trailblazer::Activity.merge( Trailblazer::Activity::Wrap.initial_activity, upload_wrap )

        signal, (options, flow_options, *ret) = more_nested.(
          [
            options = {},

            {
              stack:         Activity::Trace::Stack.new,
              introspection: { } # TODO: crashes without :debug.
            },
          ],

          runner:        Wrap::Runner,
          wrap_runtime:  Hash.new(wrap_alterations),      # apply to all tasks!
          wrap_static:   wrap_static,
        )

        # upload should contain only one 1.
        options.inspect.must_equal %{{:upload=>[1], \"bits\"=>64}}

        tree = Activity::Trace::Present.tree(flow_options[:stack].to_a)

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
        [ :insert_before!, "task_wrap.call_task", node: [ Activity::Wrap::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
        [ :insert_before!, "End.default", node: [ Activity::Wrap::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Call, Activity::Trace.method(:capture_args), signal: Circuit::Right ) },
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Activity[:End], Activity::Trace.method(:capture_return), signal: Circuit::Right ) },
      ]

      signal, (options, flow_options) = activity.(
        [
          options = {},
          {
            # Trace specific:
            stack:      Activity::Trace::Stack.new,
            introspection:      { Model => { id: "outsideg.Model" }, Uuid => { id: "outsideg.Uuid" } } # optional, eg. per Activity.
          }
        ],

        # wrap_static
        wrap_static:  Hash.new( Trailblazer::Activity::Wrap.initial_activity ), # per activity?
        wrap_runtime: Hash.new(wrap_alterations), # dynamic additions from the outside (e.g. tracing), also per task.
        runner:       Wrap::Runner
      )

      signal.must_equal activity.end_events.first # the actual activity's End signal.
      options.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})


      puts tree = Activity::Trace::Present.tree(flow_options[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- outsideg.Model
|-- #<Trailblazer::Activity:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:.rb:11 (lambda)>
|   |-- #<Trailblazer::Activity:>
|   |   |-- #<Trailblazer::Circuit::Start:>
|   |   |-- #<Proc:.rb:12 (lambda)>
|   |   |-- #<Trailblazer::Circuit::End:>
|   |   `-- #<Trailblazer::Activity:>
|   |-- #<Proc:.rb:13 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Activity:>
|-- outsideg.Uuid
`-- #<Trailblazer::Circuit::End:>}
    end
  end
end

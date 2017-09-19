require "test_helper"

class WrapTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  Activity         = Trailblazer::Activity
  SpecialDirection = Class.new
  Wrap             = Activity::Wrap

  Model     = ->((options), **circuit_options) { options["model"]=String; [ Circuit::Right, [options], **circuit_options] }
  Uuid      = ->((options), **circuit_options) { options["uuid"]=999;     [ SpecialDirection, [options], **circuit_options] }
  Save      = ->((options), **circuit_options) { options["saved"]=true;   [ Circuit::Right, [options], **circuit_options] }
  Upload    = ->((options), **circuit_options) { options["bits"]=64;      [ Circuit::Right, [options], **circuit_options] }
  Cleanup   = ->((options), **circuit_options) { options["ok"]=true;      [ Circuit::Right, [options], **circuit_options] }

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

    #---
    #-
    describe "Wrap::Runner#call with invalid input" do
      let(:wrap_alterations) do
        [
          [ :insert_before!, "task_wrap.call_task", node: [ Activity::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
          [ :insert_before!, "End.default", node: [ Activity::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        ]
      end

      # no :wrap_alterations, default Wrap
      it do
        assert_raises do
          signal, *args = more_nested.( [ options = {}, { runner: Wrap::Runner }, static_wraps={} ] )
        end.to_s.must_equal %{Please provide :wrap_runtime}
      end

      # specific wrap for A, default for B.
      it do
        only_for_wrap = ->((options, flow_options, cdfg, original_args)) do
          _options, _ = original_args
          _options[:upload] ||= []
          _options[:upload]<<1

          [ Circuit::Right, [options, flow_options, cdfg, original_args] ]
        end
        upload_wrap   = [ [ :insert_before!, "task_wrap.call_task", node: [ only_for_wrap, { id: "task_wrap.upload" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ] ]

        wrap_static         = Hash.new( Trailblazer::Activity::Wrap.initial_activity )
        wrap_static[Upload] = Trailblazer::Activity.merge( Trailblazer::Activity::Wrap.initial_activity, upload_wrap )

        signal, (options, flow_options, *ret) = more_nested.(
          [
            options = {},
            {
              runner: Wrap::Runner,
              wrap_runtime:  Hash.new(wrap_alterations),      # apply to all tasks!

              stack:         Activity::Trace::Stack.new,
              introspection: { } # TODO: crashes without :debug.
            },

            wrap_static
          ],
          # runner: Wrap::Runner,
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
        [ :insert_before!, "task_wrap.call_task", node: [ Activity::Trace.method(:capture_args), { id: "task_wrap.capture_args" } ],   outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true }  ],
        [ :insert_before!, "End.default", node: [ Activity::Trace.method(:capture_return), { id: "task_wrap.capture_return" } ], outgoing: [ Circuit::Right, {} ], incoming: Proc.new{ true } ],
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Call, Activity::Trace.method(:capture_args), signal: Circuit::Right ) },
        # ->(wrap_circuit) { Circuit::Activity::Before( wrap_circuit, Wrap::Activity[:End], Activity::Trace.method(:capture_return), signal: Circuit::Right ) },
      ]
h=Hash.new(wrap_alterations)
puts "xx@@@@@ #{h.object_id.inspect}"
      signal, (options, flow_options) = activity.(
        [
          options = {},
          {
            # Wrap::Runner specific:
            # runner:       Wrap::Runner,
          # wrap_static:  Hash.new( Trailblazer::Activity::Wrap.initial_activity ), # per activity?

            # Trace specific:
            stack:      Activity::Trace::Stack.new,
          introspection:      { Model => { id: "outsideg.Model" }, Uuid => { id: "outsideg.Uuid" } } # optional, eg. per Activity.
          },

          # wrap_static
          Hash.new( Trailblazer::Activity::Wrap.initial_activity ), # per activity?

        ],

        wrap_runtime: h, # dynamic additions from the outside (e.g. tracing), also per task.
        runner: Wrap::Runner
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

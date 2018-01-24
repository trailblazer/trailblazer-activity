require "test_helper"

class WrapTest < Minitest::Spec
  Circuit          = Trailblazer::Circuit
  Activity         = Trailblazer::Activity
  SpecialDirection = Class.new
  Wrap             = Activity::TaskWrap

  Model     = ->((options, *args), **circuit_options) { options = options.merge("model" => String); [ Activity::Right, [options, *args], **circuit_options] }
  Uuid      = ->((options, *args), **circuit_options) { options = options.merge("uuid" => 999);     [ SpecialDirection, [options, *args], **circuit_options] }
  Save      = ->((options, *args), **circuit_options) { options = options.merge("saved" => true);   [ Activity::Right, [options, *args], **circuit_options] }
  Upload    = ->((options, *args), **circuit_options) { options = options.merge("bits" => 64);      [ Activity::Right, [options, *args], **circuit_options] }
  Cleanup   = ->((options, *args), **circuit_options) { options = options.merge("ok" => true);      [ Activity::Right, [options, *args], **circuit_options] }

  MyInject  = ->((options)) { [ Activity::Right, options.merge( current_user: Module ) ] }

  describe "running with TaskWrap.arguments_for_call but no configured taskWrap" do
    it "executes activity" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a)#, extension: [ Activity::TaskWrap::Merge.new(extension_adds) ]
      end

      args = [ {seq: []}, {} ]

      event, (options, _) = activity.( args, argumenter: [ Activity::TaskWrap.method(:arguments_for_call) ] )

      options.must_equal(:seq=>[:a])
    end
  end

  describe "storing TaskWrap::Merge via :extension API" do
    # {TaskWrap API} extension task
    TaskWrap_Extension_task = ->( (wrap_config, original_args), **circuit_options ) do
      (ctx, b), c = original_args

      ctx[:seq] << "Hi from taskWrap!"

      return Activity::Right, [ wrap_config, [[ctx, b], c] ]
    end

    it do
      extension_adds = Module.new do
        extend Activity::Path::Plan()

        task TaskWrap_Extension_task, before: "task_wrap.call_task" # "Hi from taskWrap!"
      end

      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a), extension: [ Activity::TaskWrap::Merge.new(extension_adds) ]
      end

      # pp activity.static_task_wrap.values.first.decompose

      args = [ {seq: []}, {} ]

      # event, (options, _) = activity.( *Wrap.arguments_for_call( activity, args ) )
      event, (options, _) = activity.( args, argumenter: [ Activity::TaskWrap.method(:arguments_for_call) ] )

      options.must_equal(:seq=>["Hi from taskWrap!", :a])
    end
  end


  #- tracing

  describe "nested trailing" do
    let (:more_nested) do
      activity = Module.new do
        extend Activity::Path()
        task task: Upload
      end
    end

    let (:nested) do
      _more_nested = more_nested

      activity = Module.new do
        extend Activity::Path()
        task task: Save
        task task: _more_nested, _more_nested.outputs[:success] => :success
        task task: Cleanup
      end
    end

    let (:activity) do
      _nested = nested

      activity = Module.new do
        extend Activity::Path()
        task task: Model
        task task: _nested, _nested.outputs[:success] => :success, id: "A"
        task task: Uuid, Output(SpecialDirection, :success) => :success
      end
    end

    describe "plain TaskWrap without additional steps" do
      it do
        signal, (options, flow_options) = activity.(
        [
          options = {},
          {},
        ],

        wrap_runtime: Hash.new, # dynamic additions from the outside (e.g. tracing), also per task.
        runner: Wrap::Runner,
        wrap_static: Hash.new( Wrap.initial_activity ), # per activity?
      )

      signal.must_equal activity.outputs[:success].signal # the actual activity's End signal.
      options.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})
      end
    end

    #---
    #-
    describe "Wrap::Runner#call with :wrap_runtime" do
      let(:wrap_alterations) do
        Module.new do
          extend Activity::Path::Plan()

          task Wrap::Trace.method(:capture_args),   id: "task_wrap.capture_args",   before: "task_wrap.call_task"
          task Wrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
        end
      end

      # no :wrap_alterations, default Wrap
      it "raises an exception when :wrap_runtime parameter is missing" do
        assert_raises do
          signal, *args = more_nested.( [ options = {}, { } ], runner: Wrap::Runner, wrap_static: {} )
        end.to_s.must_equal %{missing keyword: wrap_runtime}
      end

      # specific wrap for A, default for B.
      it "specific wrap for A, default for B" do
        only_for_wrap = ->(( cdfg, original_args), **circuit_options) do
          _options, _ = original_args[0]
          _options[:upload] ||= []
          _options[:upload]<<1

          [ Activity::Right, [ cdfg, original_args], circuit_options ]
        end

        upload_wrap  = Module.new do
          extend Activity::Path::Plan()
          task only_for_wrap, id: "task_wrap.upload", before: "task_wrap.call_task"
        end

        wrap_static         = Hash.new( Wrap.initial_activity )
        wrap_static[Upload] = Trailblazer::Activity::Path::Plan.merge( Wrap.initial_activity, upload_wrap )

        signal, (options, flow_options, *ret) = more_nested.(
          [
            options = {},

            {
              stack:         Activity::Trace::Stack.new,
            },
          ],

          runner:        Wrap::Runner,
          wrap_runtime:  Hash.new(wrap_alterations),      # apply to all tasks!
          wrap_static:   wrap_static,
          # introspection: { } # TODO: crashes without :debug.

          argumenter: [ Activity::Introspect.method(:arguments_for_call) ]
        )

        # upload should contain only one 1.
        options.inspect.must_equal %{{:upload=>[1], \"bits\"=>64}}

        tree = Activity::Trace::Present.tree(flow_options[:stack].to_a)

        # all three tasks should be executed.
        tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<struct Trailblazer::Activity::Start semantic=:default>
|-- #<Proc:.rb:12 (lambda)>
`-- #<struct Trailblazer::Activity::End semantic=:success>}
      end
    end

    #---
    #- Tracing
    it "trail" do
      wrap_alterations = Module.new do
        extend Activity::Path::Plan()
        task Wrap::Trace.method(:capture_args),   id: "task_wrap.capture_args", before: "task_wrap.call_task"
        task Wrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
      end

      signal, (options, flow_options) = activity.(
        [
          options = {},
          {
            # Trace specific:
            stack:      Activity::Trace::Stack.new,
          }
        ],

        # wrap_static
        wrap_static:  Hash.new( Wrap.initial_activity ), # per activity?
        wrap_runtime: Hash.new(wrap_alterations), # dynamic additions from the outside (e.g. tracing), also per task.
        runner:       Wrap::Runner,
        introspect:      { Model => { id: "outsideg.Model" }, Uuid => { id: "outsideg.Uuid" } }, # optional, eg. per Activity.
      )

      signal.must_equal activity.outputs[:success].signal # the actual activity's End signal.
      options.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})

pp flow_options
      puts tree = Activity::Trace::Present.tree(flow_options[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<struct Trailblazer::Activity::Start semantic=:default>
|-- outsideg.Model
|-- #<Module:>
|   |-- #<struct Trailblazer::Activity::Start semantic=:default>
|   |-- #<Proc:.rb:11 (lambda)>
|   |-- #<Module:>
|   |   |-- #<struct Trailblazer::Activity::Start semantic=:default>
|   |   |-- #<Proc:.rb:12 (lambda)>
|   |   `-- #<struct Trailblazer::Activity::End semantic=:success>
|   |-- #<Proc:.rb:13 (lambda)>
|   `-- #<struct Trailblazer::Activity::End semantic=:success>
|-- outsideg.Uuid
`-- #<struct Trailblazer::Activity::End semantic=:success>}
    end
  end
end

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

      event, (options, _) = Activity::TaskWrap.invoke(activity, args)

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

        task task: T.def_task(:a), Activity::DSL::Extension.new( Activity::TaskWrap::Merge.new(extension_adds) ) => true
      end

      args = [ {seq: []}, {} ]

      event, (options, _) = Activity::TaskWrap.invoke(activity, args)

      options.must_equal(:seq=>["Hi from taskWrap!", :a])
    end
  end


  #- tracing

  describe "nested trailing" do
    let (:more_nested) do
      activity = Module.new do
        extend Activity::Path(name: :bottom)
        task task: Upload
      end
    end

    let (:nested) do
      _more_nested = more_nested

      activity = Module.new do
        extend Activity::Path(name: :middle)
        task task: Save
        task task: _more_nested, _more_nested.outputs[:success] => Track(:success)
        task task: Cleanup
      end
    end

    let (:activity) do
      _nested = nested

      activity = Module.new do
        extend Activity::Path(name: :top)
        task task: Model
        task task: _nested, _nested.outputs[:success] => Track(:success), id: "A"
        task task: Uuid, Output(SpecialDirection, :success) => Track(:success)
      end
    end

    describe "plain TaskWrap without additional steps" do
      it do
        signal, (options, flow) = Activity::TaskWrap.invoke(activity, [options = {}, {}] )

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

        _more_nested = more_nested
        more_nested = Module.new do
          extend Trailblazer::Activity::Path()
          merge! _more_nested
          self[:wrap_static] = wrap_static # we need to set :wrap_static on the activity.
        end

        signal, (ctx, flow) = Activity::TaskWrap.invoke( more_nested,
          [
            {},
            {
              # stack:        Activity::Trace::Stack.new,
            },
          ],
        )

        # upload should contain only one 1.
        ctx.inspect.must_equal %{{:upload=>[1], \"bits\"=>64}}

#         tree = Activity::Trace::Present.tree(flow[:stack].to_a)

#         # all three tasks should be executed.
#         tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Activity::Start semantic=:default>
# |-- #<Proc:.rb:12 (lambda)>
# `-- #<Trailblazer::Activity::End semantic=:success>}
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

      signal, (options, flow) = Activity::TaskWrap.invoke(activity,
        [
          {},
          {
            # Trace specific:
            stack:      Activity::Trace::Stack.new,
          }
        ],

        # wrap_static
        wrap_runtime: Hash.new(wrap_alterations), # dynamic additions from the outside (e.g. tracing), also per task.
      )

      signal.must_equal activity.outputs[:success].signal # the actual activity's End signal.
      options.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})

      puts tree = Activity::Trace::Present.tree(flow[:stack].to_a)

      tree.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{`-- #<Trailblazer::Activity: {top}>
    |-- Start.default
    |-- #<Proc:.rb:9 (lambda)>
    |-- A
    |   |-- Start.default
    |   |-- #<Proc:.rb:11 (lambda)>
    |   |-- #<Trailblazer::Activity: {bottom}>
    |   |   |-- Start.default
    |   |   |-- #<Proc:.rb:12 (lambda)>
    |   |   `-- End.success
    |   |-- #<Proc:.rb:13 (lambda)>
    |   `-- End.success
    |-- #<Proc:.rb:10 (lambda)>
    `-- End.success}
    end

    # FIXME
    describe "public interface" do
      it "what" do
        wrap_alterations = Module.new do
          extend Activity::Path::Plan()
          task Wrap::Trace.method(:capture_args),   id: "task_wrap.capture_args", before: "task_wrap.call_task"
          task Wrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
        end

        # these options will never change anywhere.
        circuit_options = {
          runner:       Activity::TaskWrap::Runner,
          wrap_runtime: Hash.new(wrap_alterations),

          activity:     { wrap_static: {}, adds: {} } # i am overridden
        }


        signal, (ctx, flow), circuit_options =
        Activity::TaskWrap::Runner.( activity,
          [
            {},
            {
              # Trace specific:
              stack:      Activity::Trace::Stack.new,
            }
          ],

          circuit_options
        )

        ctx.must_equal({"model"=>String, "saved"=>true, "bits"=>64, "ok"=>true, "uuid"=>999})

              puts tree = Activity::Trace::Present.tree(flow[:stack].to_a)
      end
    end
  end
end

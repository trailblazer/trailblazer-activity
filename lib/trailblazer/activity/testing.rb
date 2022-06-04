# DISCUSS: move to trailblazer-activity-test ?

# Helpers to quickly create steps and tasks.
module Trailblazer
  module Activity::Testing
    # Creates a module with one step method for each name.
    #
    # @example
    #   extend T.def_steps(:create, :save)
    def self.def_steps(*names)
      Module.new do
        module_function
        names.each do |name|
          define_method(name) do | ctx, ** |
            ctx[:seq] << name
            ctx.key?(name) ? ctx[name] : true
          end
        end
      end
    end

    # Creates a method instance with a task interface.
    #
    # @example
    #   task task: T.def_task(:create)
    def self.def_task(name)
      Module.new do
        define_singleton_method(name) do | (ctx, flow_options), ** |
          ctx[:seq] << name
          signal = ctx.key?(name) ? ctx[name] : Activity::Right

          return signal, [ctx, flow_options]
        end
      end.method(name)
    end

    def self.def_tasks(*names)
      Module.new do
        module_function
        names.each do |name|
          define_method(name) do | (ctx, flow_options), ** |
            ctx[:seq] << name
            signal = ctx.key?(name) ? ctx[name] : Activity::Right

            return signal, [ctx, flow_options]
          end
        end
      end
    end

    module Assertions
        Activity  = Trailblazer::Activity
        Inter     = Trailblazer::Activity::Schema::Intermediate
        Schema    = Trailblazer::Activity::Schema
        TaskWrap  = Trailblazer::Activity::TaskWrap

        # @param :seq String What the {:seq} variable in the result ctx looks like. (expected seq)
        def assert_call(activity, terminus: :success, seq: "[]", **ctx_variables)
          # Call without taskWrap!
          signal, (ctx, _) = activity.([{seq: [], **ctx_variables}, _flow_options = {}]) # simply call the activity with the input you want to assert.

          assert_call_for(signal, ctx, terminus: terminus, seq: seq, **ctx_variables)
        end

        # Use {TaskWrap.invoke} to call the activity.
        def assert_invoke(activity, terminus: :success, seq: "[]", circuit_options: {}, **ctx_variables) # DISCUSS: only for {activity} gem?
          signal, (ctx, _flow_options) = TaskWrap.invoke(
            activity,
            [
              {seq: [], **ctx_variables},
              {}                          # flow_options
            ],
            **circuit_options
          )

          assert_call_for(signal, ctx, terminus: terminus, seq: seq, **ctx_variables)
        end

        def assert_call_for(signal, ctx, terminus: :success, seq: "[]", **ctx_variables)
          assert_equal signal.to_h[:semantic], terminus, "assert_call expected #{terminus} terminus, not #{signal}. Use assert_call(activity, terminus: #{signal.to_h[:semantic]})"

          assert_equal ctx.inspect, {seq: "%%%"}.merge(ctx_variables).inspect.sub('"%%%"', seq)
        end

        module Implementing
          extend Activity::Testing.def_tasks(:a, :b, :c, :d, :f, :g)

          Start = Activity::Start.new(semantic: :default)
          Failure = Activity::End(:failure)
          Success = Activity::End(:success)
        end

        # TODO: Remove this once all it's references are removed
        def implementing
          Implementing
        end

        def flat_activity
          return @_flat_activity if defined?(@_flat_activity)

          intermediate = Inter.new(
            {
              Inter::TaskRef("Start.default")      => [Inter::Out(:success, :B)],
              Inter::TaskRef(:B, additional: true) => [Inter::Out(:success, :C)],
              Inter::TaskRef(:C)                   => [Inter::Out(:success, "End.success")],
              Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
            },
            ["End.success"],
            ["Start.default"], # start
          )

          implementation = {
            "Start.default" => Schema::Implementation::Task(st = Implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
            :B => Schema::Implementation::Task(b = Implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  []),
            :C => Schema::Implementation::Task(c = Implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  []),
            "End.success" => Schema::Implementation::Task(_es = Implementing::Success, [Activity::Output(Implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
          }

          schema = Inter.(intermediate, implementation)

          @_flat_activity = Activity.new(schema)
        end

        def nested_activity
          return @_nested_activity if defined?(@_nested_activity)

          intermediate = Inter.new(
            {
              Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
              Inter::TaskRef(:B, more: true)  => [Inter::Out(:success, :D)],
              Inter::TaskRef(:D) => [Inter::Out(:success, :E)],
              Inter::TaskRef(:E) => [Inter::Out(:success, "End.success")],
              Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
            },
            ["End.success"],
            ["Start.default"] # start
          )

          implementation = {
            "Start.default" => Schema::Implementation::Task(st = Implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
            :B => Schema::Implementation::Task(b = Implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  []),
            :D => Schema::Implementation::Task(c = bc, [Activity::Output(Implementing::Success, :success)],                  []),
            :E => Schema::Implementation::Task(e = Implementing.method(:f), [Activity::Output(Activity::Right, :success)],                  []),
            "End.success" => Schema::Implementation::Task(_es = Implementing::Success, [Activity::Output(Implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
          }

          schema = Inter.(intermediate, implementation)

          @_nested_activity = Activity.new(schema)
        end

        alias_method :bc, :flat_activity
        alias_method :bde, :nested_activity

        # Tests {:circuit} and {:outputs} fields so far.
        def assert_process_for(process, *args)
          semantics, circuit = args[0..-2], args[-1]

          inspects = semantics.collect { |semantic| %{#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=#{semantic.inspect}>, semantic=#{semantic.inspect}>} }

          assert_equal %{[#{inspects.join(", ")}]}, process.to_h[:outputs].inspect

          assert_circuit(process, circuit)

          process
        end

        def assert_circuit(schema, circuit)
          cct = Cct(schema)

          cct = cct.gsub("#<Trailblazer::Activity::TaskBuilder::Task user_proc=", "<*")
          assert_equal %{#{circuit}}, cct
        end

      def Cct(activity)
        Trailblazer::Developer::Render::Circuit.(activity, inspect_task: Trailblazer::Activity::Testing.method(:render_task))
      end
    end

    # Use this in {#Cct}.
    def self.render_task(proc)
      Activity::Introspect.render_task(proc)
    end
  end
end

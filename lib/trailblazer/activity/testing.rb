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
          return Activity::Right, [ctx, flow_options]
        end
      end.method(name)
    end

    def self.def_tasks(*names)
      Module.new do
        module_function
        names.each do |name|
          define_method(name) do | (ctx, flow_options), ** |
            ctx[:seq] << name
            result = ctx.key?(name) ? ctx[name] : true

            return (result ? Activity::Right : Activity::Left), [ctx, flow_options]
          end
        end
      end
    end

    module Assertions
        def Cct(activity)
          cct = Trailblazer::Developer::Render::Circuit.(activity)
        end

        def assert_process_for(process, *args)
          semantics, circuit = args[0..-2], args[-1]

          inspects = semantics.collect { |semantic| %{#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=#{semantic.inspect}>, semantic=#{semantic.inspect}>} }

          process.to_h[:outputs].inspect.must_equal %{[#{inspects.join(", ")}]}

          assert_circuit(process, circuit)

          process
        end

        def assert_circuit(schema, circuit)
          cct = Cct(schema)
          cct = cct.gsub("#<Trailblazer::Activity::TaskBuilder::Task user_proc=", "<*")
          cct.must_equal %{#{circuit}}
        end
    end
  end
end

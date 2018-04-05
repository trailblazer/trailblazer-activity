# DISCUSS: move to trailblazer-activity-test ?

# Helpers to quickly create steps and tasks.
module Trailblazer::Activity::Testing
  # Creates a module with one step method for each name.
  #
  # @example
  #   extend T.def_steps(:create, :save)
  def self.def_steps(*names)
    Module.new do
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
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end.method(name)
  end
end

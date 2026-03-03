 module Trailblazer
  class Activity
    class Circuit
      # Executes a Circuit instance, implementing the code flow logic.
      # A circuit is basically a hash of tasks pointing to their following tasks,
      # keyed by a signal.
      class Processor
        # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
        def self.call(circuit, ctx, lib_ctx, signal, runner:, **circuit_options) # FIXME: allow {:start_task}.
          # puts "@@@@@??? #{circuit.inspect}"
          # id, task, invoker, circuit_options_to_merge = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.
          node = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.

          loop do
          # id = node.first # TODO: it always should be [id, node]
            puts ">>>Processor #{node[0].inspect} #{node[3]}"
            ctx, lib_ctx, signal = runner.(node, ctx, lib_ctx, signal, **circuit_options, runner: runner)

            node = circuit.resolve(node, signal)

            return ctx, lib_ctx, signal unless node
            # unless ()

              # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
            # end
          end
        end

        # DISCUSS: this could, when overridden, allow wrap_runtime?
        # This is the only overridable part of Processor where we know,
        # at runtime, what is the next step.

        class Node
          class Runner
            def self.call(node, ctx, lib_ctx, signal, **circuit_options)
              id, task, invoker, _, process, node_process_options = node

# pp node[2..6]
              # puts " process_node [#{id}]: #{process.inspect} invoker: #{invoker}"

# puts ">>>>>>> @@@@@ #{id} > #{node_process_options.inspect} === #{circuit_options},,,,,,,,,,,,,, #{node[4]}"

# raise "we're leaking config into children calls here. because node contains options that are hardcore-mixed with circuit_options"
              process.(node, ctx, lib_ctx, signal, circuit_options, **node_process_options) # FIXME: we're leaking config into children calls here.
            end

          end
        end
      end
    end # Circuit
  end
end



        # def raise_illegal_signal_error!(task, last_signal, outputs, **circuit_options)
        #   raise IllegalSignalError.new(
        #     task,
        #     **circuit_options,
        #     signal: last_signal,
        #     outputs: @map[task],
        #   )
        # end

        # # Common reasons to raise IllegalSignalError are when returning signals from
        # #   * macros which are not registered
        # #   * subprocesses where parent process have not registered that signal
        # #   * ciruit interface steps, for example: `step task: method(:validate)`
        # class IllegalSignalError < RuntimeError
        #   attr_reader :task, :signal

        #   def initialize(task, signal:, outputs:, exec_context:, **)
        #     @task = task
        #     @signal = signal

        #     message = "#{exec_context.class}:\n" \
        #       "\e[31mUnrecognized signal `#{signal.inspect}` returned from #{task.inspect}. Registered signals are:\e[0m\n" \
        #       "\e[32m#{outputs.keys.map(&:inspect).join("\n")}\e[0m"

        #     super(message)
        #   end
        # end

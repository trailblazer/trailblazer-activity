module Trailblazer
  module Activity::Magnetic
    module DSL
      # each "line" in the DSL adds an element, the entire line is processed here.
      module ProcessElement
        module_function
        # add new task with Polarizations
        # add new connections
        # add new ends
        # passes through :group/:before (sequence options)
        def call(task, options={}, id:raise, strategy:raise, sequence_options:{}, &block)
          # 2. compute default Polarizations by running the strategy
          strategy, args = strategy
          magnetic_to, plus_poles = strategy.( task, args )

          # 3. process user options
          arr = ProcessOptions.(id, options, args[:plus_poles], &block)

          _plus_poles = arr.collect { |cfg| cfg[0] }.compact
          adds       = arr.collect { |cfg| cfg[1] }.compact.flatten(1)

          # 4. merge them with the default Polarizations
          plus_poles = plus_poles.merge( Hash[_plus_poles] )


          # 5. add the instruction for the actual task: {seq.add(step, polarizations)}
          adds = [
            [ :add, [id, [ magnetic_to, task, plus_poles.to_a ], sequence_options] ],
            *adds
          ]
        end
      end

      # Generate PlusPoles and additional sequence alterations from the DSL options such as
      #   Output(:success) => End("my.new")
      module ProcessOptions
        module_function

        # Output => target (End/"id"/:color)
        # @return [PlusPole]
        # @return additional alterations
        #
        # options:
        #   { DSL::Output[::Semantic] => target }
        #
        def call(id, options, outputs, &block)
          options.collect { |key, task| process_tuple(id, key, task, outputs, &block) }
        end

        def process_tuple(id, output, task, outputs, &block)
          output = output_for(output, outputs) if output.kind_of?(DSL::Output::Semantic)

          if task.kind_of?(Circuit::End)
            new_edge = "#{id}-#{output.signal}"

            [
              [ output, new_edge ],

              [[ :add, [task.instance_variable_get(:@name), [ [new_edge], task, [] ], group: :end] ]]
            ]
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{output.signal}-#{task}"
            [
              [ output, new_edge ],

              [[ :magnetic_to, [ task, [new_edge] ] ]],
            ]
          # procs come from DSL calls such as `Path() do ... end`.
          elsif task.is_a?(Proc)
            start_color, adds = task.(block)

            [
              [ output, start_color ],
              # TODO: this is a pseudo-"merge" and should be public API at some point.
              adds[1..-1] # drop start
            ]
          else # An additional plus polarization. Example: Output => :success
            [
              [ output, task ]
            ]
          end
        end

        # @param semantic DSL::Output::Semantic
        def output_for(semantic, outputs)
          # DISCUSS: review PlusPoles#[]
          output, _ = outputs.instance_variable_get(:@plus_poles)[semantic.value]
          output or raise("Couldn't find existing output for `#{semantic.value.inspect}`.")
        end
      end # OptionsProcessing

      # DSL datastructures
      module Output
        Semantic = Struct.new(:value)
      end
    end # DSL
  end
end

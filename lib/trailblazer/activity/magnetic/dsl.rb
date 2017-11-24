module Trailblazer
  module Activity::Magnetic
    module DSL
      class Polarization
        def initialize( output:, color: )
          @output, @color = output, color
        end

        def call(magnetic_to, plus_poles, options)
          [
            magnetic_to,
            plus_poles.merge( @output => @color ) # this usually adds a new Output to the task.
          ]
        end
      end # Polarization

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
        def call(id, options, initial_plus_poles, &block)
          polarization, adds =
            options.
              collect { |key, task|
                # this method call is the only thing that really matters here. # TODO: make this transformation a bit more obvious.
                process_tuple(id, key, task, initial_plus_poles, &block)
              }.
              inject([[],[]]) { |memo, (polarization, adds)| memo[0]<<polarization; memo[1]<<adds; memo }

          return polarization, adds.flatten(1)
        end

        def process_tuple(id, output, task, initial_plus_poles, &block)
          output = output_for(output, initial_plus_poles) if output.kind_of?(DSL::Output::Semantic)

          if task.kind_of?(Circuit::End)
            new_edge = "#{id}-#{output.signal}"

            [
              Polarization.new( output: output, color: new_edge ),
              [ [:add, [task.instance_variable_get(:@name), [ [new_edge], task, [] ], group: :end]] ]
            ]
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{output.signal}-#{task}"

            [
              Polarization.new( output: output, color: new_edge ),
              [[ :magnetic_to, [ task, [new_edge] ] ]],
            ]
          # procs come from DSL calls such as `Path() do ... end`.
          elsif task.is_a?(Proc)
            start_color, adds = task.(block)

            [
              Polarization.new( output: output, color: start_color ),
              # TODO: this is a pseudo-"merge" and should be public API at some point.
              adds[1..-1] # drop start
            ]
          else # An additional plus polarization. Example: Output => :success
            [
              Polarization.new( output: output, color: task )
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

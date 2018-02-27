module Trailblazer
  module Activity::Magnetic
    module DSL
      # This module only processes additional "wiring" options from the DSL calls
      #   Output(:success) => End("my.new")
      #
      # Returns PlusPoles and additional sequence alterations.
      module ProcessOptions
        module_function

        # Output => target (End/"id"/:color)
        # @return [PlusPole]
        # @return additional alterations
        #
        # options:
        #   { DSL::Output[::Semantic] => target }
        #
        def call(id, options, plus_poles, &block)
          polarization, adds =
            options.
              collect { |key, task|
                # this method call is the only thing that really matters here. # TODO: make this transformation a bit more obvious.
                process_tuple(id, key, task, plus_poles, &block)
              }.
              inject([[],[]]) { |memo, (polarization, adds)| memo[0]<<polarization; memo[1]<<adds; memo }

          return polarization, adds.flatten(1)
        end

        def process_tuple(id, output, task, plus_poles, &block)
          output = output_for(output, plus_poles) if output.kind_of?(Activity::DSL::OutputSemantic)

          if task.kind_of?(Activity::End)
            # raise %{An end event with semantic `#{task.to_h[:semantic]}` has already been added. Please use an ID reference: `=> "End.#{task.to_h[:semantic]}"`} if
            new_edge = "#{id}-#{output.signal}"

            [
              Polarization.new( output: output, color: new_edge ),
              [ [:add, [task.to_h[:semantic], [ [new_edge], task, [] ], group: :end]] ]
            ]
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{id}-#{output.signal}-#{task}"

            [
              Polarization.new( output: output, color: new_edge ),
              [[ :magnetic_to, [ task, [new_edge] ] ]],
            ]
          # procs come from DSL calls such as `Path() do ... end`.
          elsif task.is_a?(Proc)
            start_color, activity = task.(block)

            adds = activity.to_h[:adds]

            [
              Polarization.new( output: output, color: start_color ),
              # TODO: this is a pseudo-"merge" and should be public API at some point.
            # TODO: we also need to merge all the other states such as debug.
              adds[1..-1] # drop start
            ]
          else # An additional plus polarization. Example: Output => :success
            [
              Polarization.new( output: output, color: task )
            ]
          end
        end

        # @param semantic DSL::Output::Semantic
        def output_for(semantic, plus_poles)
          # DISCUSS: review PlusPoles#[]
          output, _ = plus_poles.instance_variable_get(:@plus_poles)[semantic.value]
          output or raise("Couldn't find existing output for `#{semantic.value.inspect}`.")
        end
      end # OptionsProcessing
    end # DSL
  end
end

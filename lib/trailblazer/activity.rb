require "trailblazer/circuit"

# TODO: move to separate gem.
require "trailblazer/option"
require "trailblazer/context"
require "trailblazer/container_chain"

module Trailblazer
  class Activity

  require "trailblazer/activity/version"
  require "trailblazer/activity/graph"
  require "trailblazer/activity/subprocess"

  require "trailblazer/activity/wrap"
  require "trailblazer/wrap/variable_mapping"
  require "trailblazer/wrap/call_task"
  require "trailblazer/wrap/trace"
  require "trailblazer/wrap/inject"
  require "trailblazer/wrap/runner"

  require "trailblazer/activity/trace"
  require "trailblazer/activity/present"


  require "trailblazer/activity/schema/sequence"

    # Only way to build an Activity.
    def self.from_wirings(wirings, &block)
      start_evt  = Circuit::Start.new(:default)
      start_args = [ start_evt, { type: :event, id: "Start.default" } ]

      start      = block ? Graph::Start( *start_args, &block ) : Graph::Start(*start_args)

      wirings.each do |wiring|
        start.send(*wiring)
      end

      new(start)
    end

    # Build an activity from a hash.
    #
    #   activity = Trailblazer::Activity.from_hash do |start, _end|
    #     {
    #       start            => { Circuit::Right => Blog::Write },
    #       Blog::Write      => { Circuit::Right => Blog::SpellCheck },
    #       Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
    #       Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
    #       Blog::Publish    => { Circuit::Right => _end }
    #     }
    #   end
    def self.from_hash(end_evt=Circuit::End.new(:default), start_evt=Circuit::Start.new(:default), &block)
      hash  = yield(start_evt, end_evt)
      graph = Graph::Start( start_evt, id: "Start.default" )

      hash.each do |source_task, connections|
        source = graph.find_all { |node| node[:_wrapped] == source_task }.first or raise "#{source_task} unknown"

        connections.each do |signal, task| # FIXME: id sucks
          if existing = graph.find_all { |node| node[:_wrapped] == task }.first
            graph.connect!( source: source[:id], target: existing, edge: [signal, {}] )
          else
            graph.attach!( source: source[:id], target: [task, id: task], edge: [signal, {}] )
          end
        end
      end

      new(graph)
    end

    def self.merge(activity, wirings)
      graph = activity.graph

      # TODO: move this to Graph
      # replace the old start node with the new one that's created in ::from_wirings.
      cloned_graph_ary = graph[:graph].collect { |node, connections| [ node, connections.clone ] }
      old_start_connections = cloned_graph_ary.delete_at(0)[1] # FIXME: what if some connection goes back to start?

      from_wirings(wirings) do |start_node, data|
        cloned_graph_ary.unshift [ start_node, old_start_connections ] # push new start node onto the graph.

        data[:graph] = ::Hash[cloned_graph_ary]
      end
    end

    require "trailblazer/activity/schema/dependencies"
    require "trailblazer/activity/schema/magnetic"
    # DSL is only supposed to know about magnetism and the generic DSL, *not* about specific edge colors
    # or Railway-oriented features such as two outgoing edges, etc.
    class DSL
      # add new task with Polarizations
      # add new connections
      # add new ends
      def self.alter_sequence(sequence, task, options={}, id:raise, strategy:raise, &block)
        # 1. sort generic options
        id          = options[:id] || task.to_s
        # magnetic_to = options[:magnetic_to] || track_color
        options     = options.reject{ |key,v| [:id, :magnetic_to].include?(key) }

        # 2. compute default Polarizations by running the strategy
        strategy, args = strategy
        magnetic_to, plus_poles = strategy.(task, args )

        # 3. process user options
        arr = process_dsl_options(sequence, id, options)

        _plus_poles = arr.collect { |cfg| cfg[0] }.compact
        adds       = arr.collect { |cfg| cfg[1] }.compact
        proc, _    = arr.collect { |cfg| cfg[2] }.compact

        # 4. merge them with the default Polarizations
        plus_poles = plus_poles.merge( Hash[_plus_poles] )

         # pp plus_poles

        # 5. seq.add step, polarizations
        sequence.add( id, [ magnetic_to, task, plus_poles.to_a ],  )
        # 6. add additional steps
        adds.each do |method, cfg| sequence.send( method, *cfg ) end
        # 7. execute blocks
        proc.() if proc # this is for nested, do we need this here?

        sequence
      end

      # Output => target (End/"id"/:color)
      # @return [PlusPole]
      # @return additional alterations
      def self.process_dsl_options(sequence, id, options)
        # key: Output
        options.collect do |key, task|
          output = key

          if task.kind_of?(Circuit::End)
            new_edge = "#{id}-#{key.signal}"

            [
              # assuming key is an Output
              # Magnetic::PlusPole.new(key, new_edge),
              [ output, new_edge ],

              [ :add, [task.instance_variable_get(:@name), [ [new_edge], task, [] ], group: :end] ]
            ]
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{key.signal}-#{task}"
            [
              Magnetic::PlusPole.new(key, new_edge),

              [ :magnetic_to, [ task, [new_edge] ] ],
            ]
          elsif task.is_a?(Proc)
            dsl = DSL.new(sequence, color = :"track_#{rand}")

            [
              [ output, color ],
              # Magnetic::PlusPole.new(key, color),
              nil,
              ->(*) { dsl.instance_exec(color, &task) }
            ]
          else # An additional plus polarization. Example: Output => :success
            [
              [ output, task ]
              #Magnetic::PlusPole.new(key, task)
            ]
          end
        end
      end

      def End(name, semantic)
         evt = Circuit::End.new(name)
        evt
      end

      def Output(signal, semantic)
        Magnetic.Output(signal, semantic)
      end

      def to_a
        @sequence.to_a
      end

      def initialize(sequence=Magnetic::Alterations.new, track_color=:success)
        # @sequence = Schema::Sequence.new
        @sequence     = sequence
        @track_color  = track_color
        # @outputs      = {}

        # these are initial pole(s) for a path.
        @initial_plus_poles = Activity::Magnetic::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Right, :success) => track_color
        ).freeze
      end

      def task(task, options={}, &block)
        # puts "!!!!task #{@sequence}"
        @sequence = DSL.alter_sequence( @sequence, task, options, id: options[:id],
          strategy: [ PoleGenerator::Path.method(:task), plus_poles: @initial_plus_poles, track_color: @track_color],
          &block )
      end
    end

    class Path
      def initialize
        # start, end

      end

      def finalize

      end
    end

    # wir wollen einmal dsl.task von_railway op und einmal DSL.new(andere_sq).instance_exec()




    module FastTrack

    end
    class FastTrack::Builder
      def keywords
        [:id, :plus_poles, :fail_fast, :pass_fast, :fast_track]
      end

      def initialize(strategy_options={})
        @strategy_options = strategy_options

        sequence = Magnetic::Alterations.new
        sequence = DSL::PoleGenerator::Path.initialize_sequence(sequence, strategy_options)
        sequence = DSL::PoleGenerator::Railway.initialize_sequence(sequence, strategy_options)
        sequence = DSL::PoleGenerator::FastTrack.initialize_sequence(sequence, strategy_options)

        @sequence = sequence
      end

      def step(*args, &block)
        add(DSL::PoleGenerator::FastTrack.method(:step), *args, &block)
      end
      def fail(*args, &block)
        add(DSL::PoleGenerator::FastTrack.method(:fail), *args, &block)
      end
      def pass(*args, &block)
        add(DSL::PoleGenerator::FastTrack.method(:pass), *args, &block)
      end

      def draft
        @sequence.to_a
      end

      def finalize()
        tripletts = draft
        # pp tripletts

        circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
      end

      # merge @strategy_options (for the track colors)
      # normalize options
      private def add(strategy, task, options, &block)
        local_options, options = normalize(options, keywords)

        @sequence = DSL.alter_sequence( @sequence, task, options, id: local_options[:id],
          strategy: [ strategy, @strategy_options.merge( local_options ) ],
          &block
        )
      end

      private def normalize(options, local_keys)
        local, foreign = {}, {}

        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return local, foreign
      end

      def to_activity
        tripletts = dsl.to_a
        # pp tripletts

        circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
      end
      def self.build
        new
        instance_exec
        to_activity
      end



      def self.initialize_sequence(sequence)
        sequence = Path.initialize_sequence(sequence)


      end
    end

    class Path
      class Builder < FastTrack::Builder
        def keywords
          [:id, :plus_poles]
        end

        def initialize(strategy_options={})
          @strategy_options = strategy_options

          sequence = Magnetic::Alterations.new
          sequence = DSL::PoleGenerator::Path.initialize_sequence(sequence, strategy_options)

          @sequence = sequence
        end

        def task(*args, &block)
          add( DSL::PoleGenerator::Path.method(:task), *args, &block )
        end
      end
    end

    def self.plan(&block)
      sequence = Magnetic::Alterations.new

      # add Start
      sequence.
        add( "Start.default", [ [], Circuit::Start.new(:default), [ Activity::Magnetic::PlusPole.new(Activity::Magnetic::Output(Circuit::Right, :success), :success) ] ], group: :start )
      # add Path End (only one)
      sequence.
        add( "End.success", [ [:success], Circuit::End.new(:success), [] ], group: :end )

      dsl = DSL.new(sequence)
      dsl.instance_exec(&block)

      tripletts = dsl.to_a
      # pp tripletts

      circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
    end

    def initialize(circuit_hash, outputs)
      @default_start_event = circuit_hash.keys.first
      @outputs             = outputs
      @circuit             = Circuit.new(circuit_hash, @outputs.keys, {})
    end

    def call(args, start_event: default_start_event, **circuit_options)
      @circuit.(
        args,
        circuit_options.merge( task: start_event) , # this passes :runner to the {Circuit}.
      )
    end

    # @return Hash
    attr_reader :outputs
    # @private
    attr_reader :circuit

    private

    attr_reader :default_start_event

    class Introspection
      # @param activity Activity
      def initialize(activity)
        @activity = activity
        @graph    = activity.graph
        @circuit  = activity.circuit
      end

      # Find the node that wraps `task` or return nil.
      def [](task)
        @graph.find_all { |node| node[:_wrapped] == task  }.first
      end
    end
  end
end

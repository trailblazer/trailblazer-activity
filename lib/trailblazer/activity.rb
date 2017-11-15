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

    require "trailblazer/activity/magnetic"

    class Builder
      extend Forwardable
      def_delegators Magnetic::DSL, :Output, :End # DISCUSS: Builder could be the DSL namespace?

      def initialize(strategy_options={})
        @strategy_options = strategy_options

        @sequence = Magnetic::Alterations.new
      end

      def draft
        @sequence.to_a
      end

      private

      # merge @strategy_options (for the track colors)
      # normalize options
      def add(strategy, task, options, &block)
        local_options, options = normalize(options, keywords)

        @sequence = Magnetic::DSL::ProcessElement.( @sequence, task, options, id: local_options[:id],
          strategy: [ strategy, @strategy_options.merge( local_options ) ],
          &block
        )
      end

      def normalize(options, local_keys)
        local, foreign = {}, {}
        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return local, foreign
      end
    end


    module FastTrack

    end
    class FastTrack::Builder < Builder
      def keywords
        [:id, :plus_poles, :fail_fast, :pass_fast, :fast_track]
      end

      def initialize(strategy_options={})
        sequence = super
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

      def finalize()
        tripletts = draft
        # pp tripletts

        circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
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
    end

    class Path
      class Builder < Builder
        def keywords
          [:id, :plus_poles]
        end

        def initialize(strategy_options={})
          sequence = super
          sequence = DSL::PoleGenerator::Path.initialize_sequence(sequence, strategy_options)

          @sequence = sequence
        end

        def task(*args, &block)
          add( DSL::PoleGenerator::Path.method(:task), *args, &block )
        end
      end
    end

    def self.plan(options={}, &block)
      builder = Path::Builder.new(
        {
          plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
            # Activity::Magnetic.Output(Circuit::Right, :success) => :success
            Activity::Magnetic.Output(Circuit::Right, :success) => nil
          ).freeze,


        }.merge(options)
      )

      # TODO: pass new edge color in block?
      builder.instance_exec( &block)

      tripletts = builder.draft
      # pp tripletts

      # circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
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

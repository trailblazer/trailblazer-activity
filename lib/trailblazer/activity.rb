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
    class DSL
      def initialize
        # @sequence = Schema::Sequence.new
        @sequence = Magnetic::Alterations.new
        @outputs  = {}
      end

      def task(task, options={})
        id = options[:id] || task.to_s

        @sequence.add( id, [ [:success], task, [ Schema::Magnetic::Output.new( Circuit::Right, :success ) ] ],  )

        process_dsl_options(id, options, @sequence)
      end

      def process_dsl_options(id, options, alterations)
        options.collect do |key, task|
          if task.kind_of?(Circuit::End)
            new_edge = "#{id}-#{key}"

            alterations.connect_to( id, { key => new_edge } )
            alterations.add( task.instance_variable_get(:@name), [ [key], task, {}, {} ], group: :end  )
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{key}-#{task}"

            alterations.connect_to(  id, { key => new_edge } )
            alterations.magnetic_to( task, [new_edge] )
          else # only an additional plus polarization going to the right (outgoing)
            # alterations.connect_to(  id, { key => key } )
          end
        end
      end

      def End(name, semantic)
        @outputs[ evt = Circuit::End.new(name) ] = semantic
        evt
      end

      def to_a
        @sequence.to_a
      end
    end

    def self.build(&block)
      dsl = DSL.new
      dsl.instance_exec(&block)
      # pp dsl
      dsl.instance_variable_get(:@sequence).
        add( "End.success", [ [:success], Circuit::End.new(:success), {}, {} ], group: :end )

      tripletts = dsl.to_a
      # pp tripletts

      # tripletts = Trailblazer::Activity::Magnetic::ConnectionFinalizer.( alterations )
      pp circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
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

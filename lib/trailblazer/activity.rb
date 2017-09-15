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
  require "trailblazer/activity/trace"
  require "trailblazer/activity/present"
  require "trailblazer/activity/wrap"

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

    def initialize(graph)
      @graph       = graph
      @start_event = @graph[:_wrapped]
      @circuit     = to_circuit(@graph) # graph is an immutable object.
    end

    # Calls the internal circuit. `start_at` defaults to the Activity's start event if `nil` is given.
    def call(start_at, *args)
      @circuit.( start_at || @start_event, *args )
    end

    def end_events
      outputs.keys
    end

    # Returns a hash mapping the circuit {Event} to its meta data.
    #
    #   activity.outputs #=> { #<End ..> => { role: :success }, #<End ..> => { role: :failure } }
    def outputs
      # DISCUSS: add more meta data?
      ::Hash[ graph.find_all { |node| graph.successors(node).size == 0 }.collect { |node| [ node[:_wrapped], { role: node[:role] } ] } ]
    end

    # @private
    attr_reader :circuit
    # @private
    attr_reader :graph

    private

    def to_circuit(graph)
      Circuit.new(graph.to_h( include_leafs: false ), end_events, {})
    end

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

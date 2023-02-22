module Trailblazer
  class Activity
    class Schema < Struct.new(:circuit, :outputs, :nodes, :config)
      # {:nodes} is passed directly from {compile_activity}. We need to store this data here.

      # @!method to_h()
      #   Returns a hash containing the schema's components.

      class Nodes < Hash
        # In Attributes we store data from Intermediate and Implementing compile-time.
        # This would be lost otherwise.
        Attributes = Struct.new(:id, :outputs, :task, :data)
      end

      # Builder for {Schema::Nodes} datastructure.
      #
      # A {Nodes} instance is a hash of Attributes, keyed by task. It turned out that
      # 90% of introspect lookups, we search for attributes for a particular *task*, not ID.
      # That's why in 0.16.0 we changed this structure.5
      #
      # Nodes{#<task> => #<Nodes::Attributes id= task= data= outputs=>}
      #
      # @private Please use {Introspect.Nodes} for querying nodes.
      def self.Nodes(nodes)
        Nodes[
          nodes.collect do |attrs|
            [
              attrs[2], # task
              Nodes::Attributes.new(*attrs).freeze
            ]
          end
        ].freeze
      end
    end # Schema
  end
end

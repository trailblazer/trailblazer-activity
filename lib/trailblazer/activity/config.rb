module Trailblazer
  module Activity::State
    # Compile-time
    #
    # DISCUSS: we could replace parts with Hamster::Hash.
    class Config
      def initialize(variables={})
        @variables = Hash[ variables.collect { |k,v| [k, v.freeze] } ].freeze
      end

      def []=(*args)
        if args.size == 2
          key, value = *args

          @variables = @variables.merge(key => value)
        else
          directive, key, value = *args

          @variables = @variables.merge( directive => {}.freeze ) unless @variables.key?(directive)

          directive_hash = @variables[directive].merge(key => value)
          @variables = @variables.merge( directive => directive_hash.freeze )
        end

        Config.new(@variables)
      end

      def [](*args)
        directive, key = *args

        return @variables[directive] if args.size == 1
        return @variables[directive][key] if @variables.key?(directive)
        nil
      end

      def to_h
        @variables
      end
    end
  end
end

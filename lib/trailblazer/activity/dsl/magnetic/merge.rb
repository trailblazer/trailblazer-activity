class Trailblazer::Activity < Module
  module Magnetic
    module Merge
      def merge!(merged)
        merged[:record].each do |key, args|
          dsl_method, *args = args

          return send( dsl_method, args[0], args[1], &args[2] ) if args[2]
          send( dsl_method, args[0], args[1] )
        end

        self
      end
    end
  end
end

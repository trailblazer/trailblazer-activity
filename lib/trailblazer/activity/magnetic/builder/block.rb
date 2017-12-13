module Trailblazer
  module Activity::Magnetic
    # Mutable DSL object.
    #
    # This is the only object mutated when building the ADDS, and it's only
    # used when using block-syntax, such as
    #   Path.plan do
    #     # ..
    #   end
    class Builder::Block
      def initialize(builder)
        @builder = builder
        @adds    = [] # mutable
      end

      # Evaluate user's block and return the new ADDS.
      # Used in Builder::plan or in nested DSL calls.
      def call(&block)
        instance_exec(&block)
        @adds
      end

      [:task, :step, :pass, :fail].each do |name| # create :step, :pass, :task, etc.
        define_method(name) { |*args, &block| capture_adds(name, *args, &block) } # def step(..) => forward to builder, track ADDS
      end

      extend Forwardable
      def_delegators :@builder, :Output, :Path, :End # TODO: make this official.

      # #task, #step, etc. are called via the immutable builder.
      def capture_adds(name, *args, &block)
        adds, *returned_options = @builder.send(name, *args, &block)
        @adds += adds
      end
    end
  end
end

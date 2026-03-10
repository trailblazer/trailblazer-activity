module Trailblazer
  class Activity
    # A terminus is just another task exposing the circuit interface,
    # returning itself as the signal.
    class Terminus < Struct.new(:semantic, keyword_init: true) # DISCUSS: make this a Node?
      def initialize(semantic:, **) # ignore other keywords so we "comply" with tracing's generic instantiation.
        super(semantic: semantic)
      end

      # Invoked in Runner.
      # A terminus is a Node that doesn't do anything but return itself as a signal,
      # bypassing all logic such as scoping.
      def call(ctx, lib_ctx, signal, **)
        return ctx, lib_ctx, self
      end

      class Success < Terminus
      end

      class Failure < Terminus
      end
    end
  end
end

# "di" step_di: order:  1. runtime, 2. { contract.class: A } (dynamic at runtime?)

=begin
  * test "stripe scenario"
    def pay!(options, stripe: Stripe.new) # can be overridden in e.g. test via runtime dependencies or container.
  * problem: HOW TO payment.stripe.engine ? step M, underscore_dots: true
  * Create["payment.stripe.engine"] = Stripe.new

=end

=begin
* In an operation, there's always a Context object that holds the Containers and the initial mutable data.
* SIMPLE/CURRENT WAY: we can simply pass this on without wrapping (no boundaries)
  * wrap for Nested, unwrap after Nested
=end

# TODO: mark/make all but mutable_options as frozen.
# The idea of Skill is to have a generic, ordered read/write interface that
# collects mutable runtime-computed data while providing access to compile-time
# information.
# The runtime-data takes precedence over the class data.
module Trailblazer
  # Holds local options (aka `mutable_options`) and "original" options from the "outer"
  # activity (aka wrapped_options).

  # only public creator: Build
  class Context # :data object:
    def initialize(wrapped_options, mutable_options)
      @wrapped_options, @mutable_options = wrapped_options, mutable_options
    end

    def [](name)
      ContainerChain.find( [@mutable_options, @wrapped_options], name )
    end

    def []=(name, value)
      @mutable_options[name] = value
    end

    def merge(hash)
      original, mutable_options = decompose

      ctx = Trailblazer::Context( original, mutable_options.merge(hash) )
    end

    # Return the Context's two components. Used when computing the new output for
    # the next activity.
    def decompose
      [ @wrapped_options, @mutable_options ]
    end




    # TODO: massive performance bottleneck. also, we could already "know" here what keys the
    # transformation wants.
    # FIXME: ToKeywordArguments()
    def to_hash
      {}.tap do |hash|
        # the "key" here is to call to_hash on all containers.
        [ @wrapped_options.to_hash, @mutable_options.to_hash ].each do |options|
          options.each { |k, v| hash[k.to_sym] = v }
        end
      end
    end
  end

  def self.Context(wrapped_options, mutable_options={})
    Context.new(wrapped_options, mutable_options)
  end
end

module Trailblazer
  class Activity
    # Since we're always assuming filters exposing a circuit interface, this has been moved
    # into the Activity namespace, yo.
    #
    # TODO: make Option a private concept, make devs use {Circuit.Step} instead.
    class Option # FIXME: remove trailblazer-option.
      def initialize(filter)
        @filter = filter
      end

      # To invoke an instance_method, additional logic is needed, e.g. figuring out the {exec_context}.
      #
      # PROBLEM: we don't know the signature of the instance_method, is it a step, is it circuit interface?
      #
      # Allows calling an instance method on {:exec_context} with any interfce, both
      # step and circuit interface are possible.
      class InstanceMethod < Option
        def call(*args, keyword_arguments: {}, exec_context:, **)
          exec_context.send(@filter, *args, **keyword_arguments)
        end

        module Ruby2_5_and_2_6 # TODO: remove once we drop Ruby < 2.7
          def call(*args, keyword_arguments: nil, exec_context: raise("No :exec_context given."), **kws)
            # Don't pass empty `keyword_arguments` because Ruby <= 2.6 passes an empty hash for `**{}`
            return exec_context.send(@filter, *args) unless keyword_arguments

            super(*args, keyword_arguments: keyword_arguments, exec_context: exec_context, **kws)
          end
        end
      end
    end
  end
end

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.7.0')
  Trailblazer::Activity::Option::InstanceMethod.prepend Trailblazer::Activity::Option::InstanceMethod::Ruby2_5_and_2_6
end

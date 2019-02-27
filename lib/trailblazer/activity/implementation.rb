module Trailblazer
  class Activity
    # Provides DSL and compilation for a {Schema::Implementation}
    # maintaining the actual tasks for a {Schema::Intermediate}.
    #
    # Exposes {Activity::Interface} so this can be used directly in other
    # workflows.
    #
    # NOTE: Work in progress!
    class Implementation
      def self.implement(intermediate, id2cfg)

        outputs_defaults = { # TODO: make this injectable and allow passing more.
          # semantic: [signal]
          success: [Activity::Right],
          failure: [Activity::Left]
        }

        id2cfg.collect do |id, cfg|

        end
      end

=begin
    implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Schema::Implementation::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Schema::Implementation::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Schema::Implementation::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }
=end


      def self.call(*args) # FIXME: shouldn't this be coming from Activity::Interface?
        @activity.(*args)
      end
    end

  end
end

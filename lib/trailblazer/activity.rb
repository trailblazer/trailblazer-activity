require "trailblazer/circuit"

module Trailblazer
  class Activity # DISCUSS: what are we doing with you?
    class Signal;         end
    class Right < Signal; end
    class Left < Signal;  end

    # signal:   actual signal emitted by the task
    # color:    the mapping, where this signal will travel to. This can be e.g. Left=>:success. The polarization when building the graph.
    #             "i am traveling towards :success because ::step said so!"
    # semantic: the original "semantic" or role of the signal, such as :success. This usually comes from the activity hosting this output.
    class Output < Struct.new(:signal, :semantic)
    end
  end # Activity
end

require "trailblazer/activity/terminus"
require "trailblazer/activity/step" # ComputeBinarySignal.
require "trailblazer/activity/invoke"

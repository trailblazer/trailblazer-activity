$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "trailblazer-circuit"

require "minitest/autorun"
require "raise"

module MiniTest::Assertions
  def assert_activity_inspect(text, subject)
    Trailblazer::Circuit::ActivityInspect(subject).must_equal text
  end

  def assert_event_inspect(text, subject)
    Trailblazer::Circuit::EndInspect(subject).must_equal(text)
  end
end


Trailblazer::Circuit::Activity.infect_an_assertion :assert_activity_inspect, :must_inspect
Trailblazer::Circuit::End.infect_an_assertion      :assert_event_inspect,    :must_inspect_end_fixme

class Trailblazer::Circuit
  def self.EndInspect(event)
    event.instance_eval { "#<#{self.class.to_s.split("::").last}: #{@name} #{@options}>" }
  end

  def self.ActivityInspect(activity)
    raise
    map, _ = activity.circuit.to_fields
    raise map.inspect
  end
end

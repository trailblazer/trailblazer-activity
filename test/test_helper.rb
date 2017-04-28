$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "trailblazer-circuit"

require "minitest/autorun"
# require "raise"

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

  def self.ActivityInspect(activity, strip: ["AlterTest::"])
    strip += ["Trailblazer::Circuit::"]
    stripped = ->(target) { strip_for(target, strip) }

    map, _ = activity.circuit.to_fields

    content = map.collect do |task, connections|
      bla =
      connections.collect do |direction, target|
        target_str = target.kind_of?(End) ? EndInspect(target) : stripped.(target)
        "#{stripped.(direction)}=>#{target_str}"
      end.join(", ")
      task_str = task.kind_of?(End) ? EndInspect(task) : stripped.(task)
      "#{task_str}=>{#{bla}}"
    end.join(", ")
    "{#{content}}"
  end

  def self.strip_for(target, strings)
    strings.each { |stripped| target = target.to_s.gsub(stripped, "") }
    target
  end
end

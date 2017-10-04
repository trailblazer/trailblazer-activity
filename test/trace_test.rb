require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Circuit::Right, *args ] }
  B = ->(*args) { [ Circuit::Right, *args ] }
  C = ->(*args) { [ Circuit::Right, *args ] }
  D = ->(*args) { [ Circuit::Right, *args ] }

  let(:activity) do
    Activity.from_hash do |start, _end|
      {
        start  => { Circuit::Right => A },
        A      => { Circuit::Right => bc },
        bc     => { bc.end_events.first => D },
      }
    end
  end

  let(:bc) do
    Activity.from_hash do |start, _end|
      {
        start  => { Circuit::Right => B },
        B      => { Circuit::Right => C },
        C      => { Circuit::Right => _end },
      }
    end
  end


  it do
    activity.({})
  end

  it do
      stack, _ = Trailblazer::Activity::Trace.( activity,
        [
          { content: "Let's start writing" }
        ]
      )
      #:trace-call end

      output = Trailblazer::Activity::Trace::Present.tree(stack)

      # output = Trailblazer::Activity::Inspect.(output)
      # puts output = output.gsub(/0x\w+/, "")

      output.must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- #<Proc:@test/trace_test.rb:4 (lambda)>
|-- #<Trailblazer::Activity:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:@test/trace_test.rb:5 (lambda)>
|   |-- #<Proc:@test/trace_test.rb:6 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Activity:>
`-- #<Proc:@test/trace_test.rb:7 (lambda)>}
  end
end

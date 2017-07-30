require "test_helper"

class AlterTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class A
  end
  class C
  end
  class B
  end

  let (:ends) { {end: { right: Circuit::End.new(:right), left: Circuit::End.new(:left) }} }

  describe "Before" do
    # Start -> End
    #       -> End
    let(:activity) do
      Circuit::Activity({id: "A/"}, ends) { |evt|
        {
          evt[:Start] => { Circuit::Right => evt[:End, :right], Circuit::Left => evt[:End, :left] },
        }
      }
    end

    # on RIGHT track.
    # Start -> End
    #       -> End
    it { activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>#<End: left {}>}}" }

    it do
      # Start -> A -> End
      #       ->      End
      _activity = Circuit::Activity::Before(activity, activity[:End, :right], A, direction: Circuit::Right )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>A, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}}"

      # Start -> A -> B -> End
      _activity = Circuit::Activity::Before(_activity, activity[:End, :right], B, direction: Circuit::Right )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>A, Left=>#<End: left {}>}, A=>{Right=>B}, B=>{Right=>#<End: right {}>}}"
    end

    # on LEFT track.
    it do
      # Start ->      End
      #       -> A -> End
      _activity = Circuit::Activity::Before(activity, activity[:End, :left], A, direction: Circuit::Left )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>A}, A=>{Left=>#<End: left {}>}}"

      # Start ->           End
      #       -> A -> B -> End
      _activity = Circuit::Activity::Before(_activity, activity[:End, :left], B, direction: Circuit::Left )
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>A}, A=>{Left=>B}, B=>{Left=>#<End: left {}>}}"
    end

    describe "multiple lines pointing to A" do
      let(:activity) do
        # Start ->   A  ->   End
        #       -> C ^  ->   End
        Circuit::Activity({id: "A/"}, ends) { |evt|
          {
            evt[:Start] => { Circuit::Right => A, Circuit::Left => C },
            C => { Circuit::Right => A, Circuit::Left => evt[:End, :left] },
            A => { Circuit::Right => evt[:End, :right] },
          }
        }
      end

      # push B before A (which has two inputs).
      it do
        # Start ->   B -> A -> End
        #       -> C ^ ->      End
        _activity = Circuit::Activity::Before(activity, A, B, direction: Circuit::Right )
        _activity.must_inspect "{#<Start: default {}>=>{Right=>B, Left=>C}, C=>{Right=>B, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}, B=>{Right=>A}}"
      end

      # with :debug option
      it do
        _activity = Circuit::Activity::Before(activity, A, B, direction: Circuit::Right, debug: { 1 => "first" } )
        _activity = Circuit::Activity::Before(_activity, C, A, direction: Circuit::Left, debug: { 2 => "second" } )
        circuit, stops, debug = _activity.circuit.to_fields
        debug.inspect.must_equal %{{:id=>\"A/\", 1=>\"first\", 2=>\"second\"}}
      end
    end

    describe ":connections" do
      describe "multiple lines pointing to A" do
        D = Class.new

        let(:activity) do

          #       -> D-v  ----------|
          # Start ->   A  ->   End  |
          #       -> C-^  ->   End <-
          Circuit::Activity({id: "A/"}, ends) { |evt|
            {
              evt[:Start] => { Circuit::Right => A, Circuit::Left => C, "to-D" => D },
              C => { Circuit::Right => A, Circuit::Left => evt[:End, :left] },
              A => { Circuit::Right => evt[:End, :right] },
              D => { Circuit::Right => A, Circuit::Left => evt[:End, :left] }
            }
          }
        end

        #- with :direction, everything points to B
        it do
          #       -> D-v  ---------------|
          # Start ->   B -> A  ->   End  |
          #       -> C-^       ->   End <-
          _activity = Circuit::Activity::Before(activity, A, B, direction: Circuit::Right )
          _activity.must_inspect "{#<Start: default {}>=>{Right=>B, Left=>C, to-D=>D}, C=>{Right=>B, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}, D=>{Right=>B, Left=>#<End: left {}>}, B=>{Right=>A}}"
        end

        #- with :predecessors, D still points to A since we say so.
        it do
          #       -> D------v  ----------|
          # Start ->   B -> A  ->   End  |
          #       -> C-^       ->   End <-
          _activity = Circuit::Activity::Before(activity, A, B, direction: Circuit::Right, predecessors: [ activity[:Start], C ] )
          _activity.must_inspect "{#<Start: default {}>=>{Right=>B, Left=>C, to-D=>D}, C=>{Right=>B, Left=>#<End: left {}>}, A=>{Right=>#<End: right {}>}, D=>{Right=>A, Left=>#<End: left {}>}, B=>{Right=>A}}"
        end
      end
    end
  end

  describe "Connect" do
    let(:activity) do
      # Start -> End
      #       -> End
      Circuit::Activity({id: "A/"}, ends) { |evt|
        {
          evt[:Start] => { Circuit::Right => evt[:End, :right], Circuit::Left => evt[:End, :left] },
        }
      }
    end

    it do
      _activity = Circuit::Activity::Before(activity, activity[:End, :right], B, direction: Circuit::Right )
      activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: right {}>, Left=>#<End: left {}>}}"

      _activity = Circuit::Activity::Connect(_activity, B, _activity[:End, :left], direction: Circuit::Left)
      _activity.must_inspect "{#<Start: default {}>=>{Right=>B, Left=>#<End: left {}>}, B=>{Right=>#<End: right {}>, Left=>#<End: left {}>}}"
    end
  end

  # Connect (e.g. decide!->End(:left))

  describe "Rewrite" do
    let(:activity) do
      Circuit::Activity({id: "A/"}, { end: { default: Circuit::End.new(:default) }, suspend: { default: Circuit::End.new(:suspend) } }) { |evt|
        {
          evt[:Start] => { Circuit::Right => evt[:End] },
        }
      }
    end

    it do
      _activity = Circuit::Activity::Rewrite(activity) do |map, evt|
        map[evt[:End]] = { "+Right" => evt[:Start] }
      end
      activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: default {}>}}"
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: default {}>}, #<End: default {}>=>{+Right=>#<Start: default {}>}}"
    end

    #- with :debug and :events option
    it do
      _activity = Circuit::Activity::Rewrite(
        activity,
        # merge debug hash!
        debug: { a: 1 },
        # merge events hash!
        events: { start: { resume: Circuit::Start.new(:resume) } }
      ) do |map, evt|
        map[evt[:Start, :resume]] = { "+Right" => Module } # is the new :resume event available?
      end

      activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: default {}>}}"
      _activity.must_inspect "{#<Start: default {}>=>{Right=>#<End: default {}>}, #<Start: resume {}>=>{+Right=>Module}}"
    end
  end
end

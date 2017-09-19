require "test_helper"

class SubprocessHelper < Minitest::Spec
  Circuit = Trailblazer::Circuit
  Activity = Trailblazer::Activity

  module Blog
    Read    = ->((options, *args), *) { options["Read"] = 1; [ Circuit::Right, [options, *args] ] }
    Next    = ->((options, *args), *) { options["NextPage"] = []; [ options["return"], [options, *args] ] }
    Comment = ->((options, *args), *) { options["Comment"] = 2; [ Circuit::Right, [options, *args] ] }
  end

  module User
    Relax   = ->((options, *args), *) { options["Relax"]=true; [ Circuit::Right, [options, *args] ] }
  end

  ### Subprocess( )
  ###
  describe "circuit with 1 level of nesting" do
    let(:blog) do
     Trailblazer::Activity.from_hash { |start, _end|
        {
          start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => _end, Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => _end }
        }
      }
    end

    let(:user) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => nested=blog  },
          nested     => { blog.end_events.first => User::Relax },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "ends before comment, on next_page" do
      user.([options = { "return" => Circuit::Right }]).must_equal([user.end_events.first, [{"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}]])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end
  end

  ### Subprocess( End1, End2 )
  ###
  describe "circuit with 2 end events in the nested process" do
    let(:blog) do
      _retry = Circuit::End.new(:retry)
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => _end, Circuit::Left => _retry },
        }
      }
    end

    let(:user) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => blog },
          blog     => { blog.end_events.first => User::Relax, blog.end_events[1] => _end },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "runs from Subprocess->default to Relax" do
      user.( [ options = { "return" => Circuit::Right } ] ).must_equal [
        user.end_events.first,
        [ {"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true} ]
      ]

      options.must_equal({"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end

    it "runs from other Subprocess end" do
      user.( [ options = { "return" => Circuit::Left } ] ).must_equal [
        user.end_events.first,
        [ {"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]} ]
      ]

      options.must_equal({"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]})
    end

    #---
    #- Subprocess( activity, start_at )
    let(:with_nested_and_start_at) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => nested=Activity::Subprocess( blog, start_event: Blog::Next ) },
          nested     => { blog.end_events.first => User::Relax },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "runs Subprocess from alternative start" do
      with_nested_and_start_at.( [options = { "return" => Circuit::Right }] ).
        must_equal [
          with_nested_and_start_at.end_events.first,
          [ {"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true} ]
        ]

      options.must_equal({"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true})
    end

    #---
    #- Subprocess(  activity, call: :__call__ ) { ... }
    describe "Subprocess with :call option" do
      let(:process) do
        class Workout
          def self.__call__((options, *args), *)
            options[:workout]   = 9

            [ direction=Circuit::Right, [options, *args] ]
          end
        end

        nested = Activity::Subprocess( Workout, call: :__call__ )

        Trailblazer::Activity.from_hash { |start, _end|
          {
            start       => { Circuit::Right => nested },
            nested      => { Circuit::Right => User::Relax },

            User::Relax => { Circuit::Right => _end }
          }
        }
      end

      it "runs Subprocess process with __call__" do
        process.( [options = { "return" => Circuit::Right }] ).
          must_equal [
            process.end_events.first,
            [{"return"=>Circuit::Right, :workout=>9, "Relax"=>true}]
          ]

        options.must_equal({"return"=>Circuit::Right, :workout=>9, "Relax"=>true})
      end
    end
  end
end

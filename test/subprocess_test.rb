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
  describe "circuit with 1 level of nesting" do # TODO: test this kind of configuration in dsl_tests somewhere.
    let(:blog) do
      Activity.build do
        task Blog::Read
        task Blog::Next, Output(Circuit::Right, :done) => "End.success", Output(Circuit::Left, :success) => :success
        task Blog::Comment
        # {
        #   start  => { Circuit::Right => Blog::Read },
        #   Blog::Read => { Circuit::Right => Blog::Next },
        #   Blog::Next => { Circuit::Right => _end, Circuit::Left => Blog::Comment },
        #   Blog::Comment => { Circuit::Right => _end }
        # }
      end
    end

    let(:user) do
      _blog = blog

      Activity.build do
        task _blog, _blog.outputs[:success] => :success
        task User::Relax
      end
    end

    it "ends before comment, on next_page" do
      user.( [options = { "return" => Circuit::Right }] ).must_equal(
        [user.outputs[:success].signal, [{"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}]]
      )

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end
  end

  ### Subprocess( End1, End2 )
  ###
  describe "circuit with 2 end events in the nested process" do
    let(:blog) do
      Activity.build do
        task Blog::Read
        task Blog::Next, Output(Circuit::Right, :success___) => :__success, Output(Circuit::Left, :retry___) => _retry=End(:retry, :retry)
      end
    end

    let(:user) do
      _blog = blog

      Activity.build do
        task _blog, _blog.outputs[:success] => :success, _blog.outputs[:retry] => "End.success"
        task User::Relax
      end
    end

    it "runs from Subprocess->default to Relax" do
      user.( [ options = { "return" => Circuit::Right } ] ).must_equal [
        user.outputs[:success].signal,
        [ {"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true} ]
      ]

      options.must_equal({"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end

    it "runs from other Subprocess end" do
      user.( [ options = { "return" => Circuit::Left } ] ).must_equal [
        user.outputs[:success].signal,
        [ {"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]} ]
      ]

      options.must_equal({"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]})
    end

    #---
    #- Subprocess( activity, start_at )
    let(:with_nested_and_start_at) do
      _blog = blog

      Activity.build do
        task Activity::Subprocess( _blog, task: Blog::Next ), _blog.outputs[:success] => :success
        task User::Relax
      end
    end

    it "runs Subprocess from alternative start" do
      with_nested_and_start_at.( [options = { "return" => Circuit::Right }] ).
        must_equal [
          with_nested_and_start_at.outputs[:success].signal,
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

            return Circuit::Right, [options, *args]
          end
        end

        subprocess = Activity::Subprocess( Workout, call: :__call__ )

        Activity.build do
          task subprocess
          task User::Relax
        end
      end

      it "runs Subprocess process with __call__" do
        process.( [options = { "return" => Circuit::Right }] ).
          must_equal [
            process.outputs[:success].signal,
            [{"return"=>Circuit::Right, :workout=>9, "Relax"=>true}]
          ]

        options.must_equal({"return"=>Circuit::Right, :workout=>9, "Relax"=>true})
      end
    end
  end
end

require "test_helper"

class OptionTest < Minitest::Spec
  describe "positional and kws" do
    class Step
      def with_positional_and_keywords(options, a:nil, **more_options)
        [ options, a, more_options ]
      end
    end

    WITH_POSITIONAL_AND_KEYWORDS = ->(options, a:nil, **more_options) do
      [ options, a, more_options ]
    end

    let(:positional) { { a: 1 } }
    let(:keywords)   { { a: 2, b: 3 } }

    it ":method with positional and kws" do
      step = Step.new

      # positional = { a: 1 }
      # keywords   = { a: 2, b: 3 }

      option = Trailblazer::Option(:with_positional_and_keywords)

      # evaluate the option.
      result = option.( positional, keywords, exec_context: step )

      result.must_equal( [{:a=>1}, 2, {:b=>3}] )

      positional.inspect.must_equal %{{:a=>1}}
      keywords.inspect.must_equal %{{:a=>2, :b=>3}}
    end

    it "lambda with positional and kws, WITH flow_options" do
      option = Trailblazer::Option(WITH_POSITIONAL_AND_KEYWORDS)

      # evaluate the option.
      result = option.( positional, keywords, { exec_context: "something" } )

      result.must_equal( [{:a=>1}, 2, {:b=>3}] )

      positional.inspect.must_equal %{{:a=>1}}
      keywords.inspect.must_equal %{{:a=>2, :b=>3}}
    end
  end
end

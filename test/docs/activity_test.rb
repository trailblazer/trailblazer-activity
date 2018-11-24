require "test_helper"

class DocsActivityTest < Minitest::Spec
  Memo = Struct.new(:body) do
    def self.find_by(*)
      Memo.new
    end

    def update_attributes(*)

    end
  end

  describe "#what" do
    it do
      #:overview
      module Memo::Update
        extend Trailblazer::Activity::Railway()

        module_function
        #
        # here goes your business logic
        #
        def find_model(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end

        def validate(ctx, params:, **)
          return true if params[:body].is_a?(String) && params[:body].size > 10
          ctx[:errors] = "body not long enough"
          false
        end

        def save(ctx, model:, params:, **)
          model.update_attributes(params)
        end

        def log_error(ctx, params:, **)
          ctx[:log] = "Some idiot wrote #{params.inspect}"
        end
        #
        # here comes the DSL describing the layout of the activity
        #
        step method(:find_model)
        step method(:validate), Output(:failure) => End(:validation_error)
        step method(:save)
        fail method(:log_error)
      end
      #:overview end

      #:overview-call
      ctx = { id: 1, params: { body: "Awesome!" } }

      event, (ctx, *) = Memo::Update.( [ctx, {}] )
      #:overview-call end
=begin
      #:overview-result
      pp ctx #=>
      {:id=>1,
       :params=>{:body=>"Awesome!"},
       :model=>#<struct DocsActivityTest::Memo body=nil>,
       :errors=>"body not long enough"}

      puts signal #=> #<Trailblazer::Activity::End semantic=:validation_error>
      #:overview-result end
=end
      ctx.inspect.must_equal %{{:id=>1, :params=>{:body=>\"Awesome!\"}, :model=>#<struct DocsActivityTest::Memo body=nil>, :errors=>\"body not long enough\"}}

      pp ctx
      pp event
    end
  end

  # circuit interface
  it do
    #:circuit-interface-create
    module Create
      extend Trailblazer::Activity::Railway()
      module_function

      #:circuit-interface-validate
      def validate((ctx, flow_options), **circuit_options)
        #~method
        is_valid = ctx[:name].nil? ? false : true

        ctx    = ctx.merge(validate_outcome: is_valid) # you can change ctx
        signal = is_valid ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        #~method end
        return signal, [ctx, flow_options]
      end
      #:circuit-interface-validate end

      step task: method(:validate)
    end
    #:circuit-interface-create end

    #:circuit-interface-call
    ctx          = {name: "Face to Face"}
    flow_options = {}

    signal, (ctx, flow_options) = Create.([ctx, flow_options], {})

    signal #=> #<Trailblazer::Activity::End semantic=:success>
    ctx    #=> {:name=>\"Face to Face\", :validate_outcome=>true}
    #:circuit-interface-call end

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:name=>\"Face to Face\", :validate_outcome=>true}}
  end
end

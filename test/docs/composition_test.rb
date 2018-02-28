require "test_helper"

class DocsCompositionTest < Minitest::Spec
### Automatic Wiring
  class SimpleRailwayInRailwayTest < Minitest::Spec
    Memo = Class.new(Memo)

    # A simple Railway and no special {End}s.
    #:simple-railway
    module Memo::Find
      extend Trailblazer::Activity::Railway()
      #~methods
      module_function

      def id_present?( ctx, params:, ** )
        params.key?(:id)
      end

      def find_model( ctx, params:, ** )
        ctx[:model] = Memo.find( params[:id] )
      end
      #~methods end
      step method(:id_present?)
      step method(:find_model)
    end
    #:simple-railway end

    #:simple-composer
    module Memo::Update
      extend Trailblazer::Activity::Railway()
      #~methods
      module_function

      def policy( ctx, ** )
        true
      end
      #~methods end
      step method(:policy)
      step task: Memo::Find, outputs: Memo::Find.outputs
    end
    #:simple-composer end

    it "with a plain Railway, only pass outputs" do
      # No :id
      event, (ctx, _) = Memo::Update.( { params: {} })
      event.to_h[:semantic].must_equal :failure

      # find fails
      event, (ctx, _) = Memo::Update.( { params: { id: nil } })
      event.to_h[:semantic].must_equal :failure

      # works
      event, (ctx, _) = Memo::Update.( { params: { id: 1 } })
      event.to_h[:semantic].must_equal :success
      ctx[:model].to_h.inspect.must_equal %{{:id=>1, :body=>\"Yo!\"}}
    end
  end

### Manual Wiring
  class RailwayWithThreeEndsInRailwayTest < Minitest::Spec
    Memo = Class.new(Memo)

    # Nested component
    #:manual-inner
    module Memo::Find
      extend Trailblazer::Activity::Railway()
      #~methods
      module_function

      def id_present?( ctx, params:, ** )
        params.key?(:id)
      end

      def find_model( ctx, params:, ** )
        ctx[:model] = Memo.find( params[:id] )
      end
      #~methods end
      step method(:id_present?), Output(:failure) => End(:id_missing)
      step method(:find_model),  Output(:failure) => End(:model_not_found)
    end
    #:manual-inner end

    #:manual-outer
    module Memo::Update
      extend Trailblazer::Activity::Railway()
      #~methods
      module_function

      def policy( ctx, ** )
        true
      end
      #~methods end
      step method(:policy)
      step task: Memo::Find,
        Memo::Find.outputs[:success]         => Track(:success),
        Memo::Find.outputs[:model_not_found] => End(:err404),
        Memo::Find.outputs[:id_missing]      => End(:id_missing)
    end
    #:manual-outer end

    it "has outer three ends" do
      # No :id
      event, (ctx, _) = Memo::Update.( { params: {} })
      event.to_h[:semantic].must_equal :id_missing

      # find fails
      event, (ctx, _) = Memo::Update.( { params: { id: nil } })
      event.to_h[:semantic].must_equal :err404

      # works! :success
      event, (ctx, _) = Memo::Update.( { params: { id: 1 } })
      event.to_h[:semantic].must_equal :success
      ctx[:model].to_h.inspect.must_equal %{{:id=>1, :body=>\"Yo!\"}}
    end

### rewire one inner end
    module Rewire
      module Memo
        Find = RailwayWithThreeEndsInRailwayTest::Memo::Find
      end

      #:rewire-outer
      module Memo::Update
        extend Trailblazer::Activity::Railway()
        #~methods
        module_function

        def policy( ctx, ** )
          true
        end
        #~methods end
        step method(:policy)
        step task: Memo::Find,
          Memo::Find.outputs[:success]         => Track(:success),
          Memo::Find.outputs[:model_not_found] => End(:err404),
          Memo::Find.outputs[:id_missing]      => Track(:failure)
      end
      #:rewire-outer end
    end

    it "connects :id_missing to :failure" do
      # No :id
      event, (ctx, _) = Rewire::Memo::Update.( { params: {} })
      event.to_h[:semantic].must_equal :failure

      # find fails
      event, (ctx, _) = Rewire::Memo::Update.( { params: { id: nil } })
      event.to_h[:semantic].must_equal :err404

      # works! :success
      event, (ctx, _) = Rewire::Memo::Update.( { params: { id: 1 } })
      event.to_h[:semantic].must_equal :success
      ctx[:model].to_h.inspect.must_equal %{{:id=>1, :body=>\"Yo!\"}}
    end

### use Subprocess() for automatic :outputs.
    module Subprocess
      module Memo
        Find = RailwayWithThreeEndsInRailwayTest::Memo::Find
      end

      #:subprocess-outer
      module Memo::Update
        extend Trailblazer::Activity::Railway()
        #~methods
        module_function

        def policy( ctx, ** )
          true
        end
        #~methods end
        step method(:policy)
        step Subprocess( Memo::Find ),
          Output(:model_not_found) => End(:err404),
          Output(:id_missing)      => Track(:failure)
      end
      #:subprocess-outer end
    end

    it "connects :id_missing to :failure" do
      # No :id
      event, (ctx, _) = Subprocess::Memo::Update.( { params: {} })
      event.to_h[:semantic].must_equal :failure

      # find fails
      event, (ctx, _) = Subprocess::Memo::Update.( { params: { id: nil } })
      event.to_h[:semantic].must_equal :err404

      # works! :success
      event, (ctx, _) = Subprocess::Memo::Update.( { params: { id: 1 } })
      event.to_h[:semantic].must_equal :success
      ctx[:model].to_h.inspect.must_equal %{{:id=>1, :body=>\"Yo!\"}}
    end
  end
end

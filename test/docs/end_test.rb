require "test_helper"

class DocsEndTest < Minitest::Spec

### Manual Wiring
  class CustomTest < Minitest::Spec
    Memo = Class.new(Memo)

    # Nested component
    #:output-end
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
      step method(:id_present?), Output(:failure) => End(:id_missing) # new semantic.
      # step method(:find_model),  Output(:failure) => End(:failure)    # existing semantic. DOESN'T WORK, YET.
      step method(:find_model),  Output(:failure) => "End.failure"    # existing end.
    end
    #:output-end end

    it "has three ends" do
      # Cct(Memo::Find.to_h[:circuit]).must_equal %{}

      # No :id
      event, (ctx, _) = Memo::Find.( { params: {} })
      event.to_h[:semantic].must_equal :id_missing

      # find fails
      event, (ctx, _) = Memo::Find.( { params: { id: nil } })
      event.to_h[:semantic].must_equal :failure

      # works! :success
      event, (ctx, _) = Memo::Find.( { params: { id: 1 } })
      event.to_h[:semantic].must_equal :success
      ctx[:model].to_h.inspect.must_equal %{{:id=>1, :body=>\"Yo!\"}}
    end
  end

end

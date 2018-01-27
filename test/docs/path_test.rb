require "test_helper"

class DocsPathTest < Minitest::Spec
  module Memo
  end

  describe "Path joins original activity" do
    it do
      #:join
      module Memo::Upsert
        extend Trailblazer::Activity::Path()
        #~methods
        extend T.def_steps(:save, :create, :populate)
        def self.find( ctx, ** )
          ctx[:seq] << :find
          ctx[:find_return]
        end
        #~methods end

        task method(:find), Output(Trailblazer::Activity::Left, :failure) => Path() do
          task Memo::Upsert.method(:create)
          task Memo::Upsert.method(:populate), Output(:success) => "save"
        end
        task method(:save), id: "save"
      end
      #:join end

      # Cct(Memo::Upsert.to_h[:circuit]).must_equal %{
      # }

      signal, (ctx, _) = Memo::Upsert.( [{ seq: [], find_return: true }] )
      ctx.must_equal({:seq=>[:find, :save], :find_return=>true})

      # take the extra Path and merge
      signal, (ctx, _) = Memo::Upsert.( [{ seq: [], find_return: false }] )
      ctx.must_equal({:seq=>[:find, :create, :populate, :save], :find_return=>false})
    end
  end
end

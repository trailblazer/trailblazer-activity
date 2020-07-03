require "test_helper"

class DocsPathTest < Minitest::Spec
  module Memo
  end

  describe "Path joins original activity" do
    it do
      #:join
      module Memo::Upsert
        extend Trailblazer::Activity::Path()
        # ~methods
        extend T.def_steps(:save, :create, :populate)
        def self.find(ctx, **)
          ctx[:seq] << :find
          ctx[:find_return]
        end
        # ~methods end

        task method(:find), Output(Trailblazer::Activity::Left, :failure) => Path() do
          task Memo::Upsert.method(:create)
          task Memo::Upsert.method(:populate), Output(:success) => "save"
        end
        task method(:save), id: "save"
      end
      #:join end

      # Cct(Memo::Upsert.to_h[:circuit]).must_equal %{
      # }

      signal, (ctx,) = Memo::Upsert.([{seq: [], find_return: true}])
      _(ctx).must_equal({:seq => %i[find save], :find_return => true})

      # take the extra Path and merge
      signal, (ctx,) = Memo::Upsert.([{seq: [], find_return: false}])
      _(ctx).must_equal({:seq => %i[find create populate save], :find_return => false})
    end
  end

  describe "#pass" do
    it do
      skip "we don't have pass yet"
      module Memo::Create
        extend Trailblazer::Activity::Path()
        # ~methods
        extend T.def_steps(:save)
        def self.find(_ctx, find_return:, seq:, **)
          seq << :find
          find_return
        end
        # ~methods end

        pass method(:find)
        pass method(:save)
      end

      pp Memo::Create.to_h[:circuit]

      signal, (ctx,) = Memo::Create.([{seq: [], find_return: true}])
      _(ctx).must_equal({:seq => %i[find save], :find_return => true})

      # both return values go straight to the next task
      signal, (ctx,) = Memo::Create.([{seq: [], find_return: false}])
      _(ctx).must_equal({:seq => %i[find save], :find_return => true})
    end
  end
end

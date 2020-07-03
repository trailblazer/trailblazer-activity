require "test_helper"

class DocsMergeTest < Minitest::Spec
  Memo = Class.new(Memo)

  #:simple-find
  module Memo::Find
    extend Trailblazer::Activity::Railway()
    # ~methods
    extend T.def_steps(:id_present?, :find_model)
    # ~methods end
    step method(:id_present?)
    step method(:find_model)
  end
  #:simple-find end

  class OneMerge_Test < Minitest::Spec
    Memo = Class.new(Memo)

    #:merge
    module Memo::Update
      extend Trailblazer::Activity::Railway()
      # ~methods
      extend T.def_steps(:policy, :update)
      # ~methods end
      step method(:policy)

      merge!(Memo::Find)

      step method(:update)
    end
    #:merge end

    it do
      # happy update path
      signal, (ctx,) = Memo::Update.([{seq: []}])
      _(ctx).must_equal({:seq => %i[policy id_present? find_model update]})
    end
  end

  class TwoMerges_Test < Minitest::Spec
    Memo = Class.new(Memo)

    module Lib
    end

    #:logger
    module Lib::Logger
      extend Trailblazer::Activity::Railway()
      # ~methods
      extend T.def_steps(:log_error, :log_success)
      # ~methods end
      fail method(:log_error),   group: :end, before: "End.failure" # always as last.
      pass method(:log_success), group: :end, before: "End.success" # always as last.
    end
    #:logger end

    #:merge-two
    module Memo::Update
      extend Trailblazer::Activity::Railway()
      # ~methods
      extend T.def_steps(:policy, :update)
      # ~methods end
      merge! Lib::Logger
      step method(:policy)

      merge!(Memo::Find)
      step method(:update)
    end
    #:merge-two end

    it do
      # puts Cct(Memo::Update.to_h[:circuit])

      # happy update path, with logger
      signal, (ctx,) = Memo::Update.([{seq: []}])
      _(ctx).must_equal({:seq => %i[policy id_present? find_model update log_success]})
    end
  end
end

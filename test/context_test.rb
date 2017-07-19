require "test_helper"

class ArgsTest < Minitest::Spec
  Context = Trailblazer::Context

  let (:immutable) { { repository: "User" } }

  let (:ctx) { ctx = Trailblazer::Context(immutable) }

  it do
    ctx = Trailblazer::Context(immutable)

    # it {  }
    #-
    # options[] and options[]=
    ctx[:model]    = Module
    ctx[:contract] = Integer
    ctx[:model]   .must_equal Module
    ctx[:contract].must_equal Integer

    # it {  }
    immutable.inspect.must_equal %{{:repository=>\"User\"}}
  end

  it "allows false/nil values" do
    ctx["x"] = false
    ctx["x"].must_equal false

    ctx["x"] = nil
    ctx["x"].must_equal nil
  end

  #- #to_hash
  it do
    ctx = Trailblazer::Context( immutable )

    # it {  }
    ctx.to_hash.must_equal( { repository: "User" } )

    # last added has precedence.
    # only symbol keys.
    # it {  }
    ctx[:a] =Symbol
    ctx["a"]=String

    ctx.to_hash.must_equal({ :repository=>"User", :a=>String })
  end

  describe "#merge" do
    it do
      ctx = Trailblazer::Context(immutable)

      merged = ctx.merge( current_user: Module )

      merged.to_hash.must_equal({:repository=>"User", :current_user=>Module})
      ctx.to_hash.must_equal({:repository=>"User"})
    end
  end




  #-
  it do
    immutable = { repository: "User", model: Module, current_user: Class }

    ctx = Trailblazer::Context(immutable) do |original, mutable|
      mutable
    end
  end
end

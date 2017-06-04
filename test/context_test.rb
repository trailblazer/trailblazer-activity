require "test_helper"

class ArgsTest < Minitest::Spec
  Context = Trailblazer::Context

  let (:immutable) { { repository: "User" } }

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



    # strip mutable, build new one
    _original, _mutable = nil, nil

    new_ctx = ctx.Build do |original, mutable| # both structures should be read-only
      _original, _mutable = original, mutable

      original.merge( a: mutable[:model] )
    end # this is our output, what do we want to tell the outer world?

    # it {  }
    _original.must_equal({:repository=>"User"})
    _mutable.must_equal({model: Module, contract: Integer})

    # writing to new doesn't change anything else
    new_ctx[:current_user] = Class
    new_ctx[:current_user].must_equal Class

     # it {  }
    immutable.inspect.must_equal %{{:repository=>\"User\"}}
    ctx.to_hash.must_equal( {:repository=>"User", :model=>Module, contract: Integer } )

    # it {  }
    new_ctx.to_hash.must_equal({ :repository=>"User", a: Module, current_user: Class })
  end

  #---
  #- ingoing data, e.g. when calling a nested operation.
  it "Input: hide data and rename" do
    ctx = Trailblazer::Context( current_user: Module, model: Class )

    new_ctx = ctx.Build do |original, mutable|
      { my_current_user: ctx[:current_user] }
    end

    new_ctx.to_hash.must_equal({:my_current_user=>Module})
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





  #-
  it do
    immutable = { repository: "User", model: Module, current_user: Class }

    ctx = Trailblazer::Context(immutable) do |original, mutable|
      mutable
    end
  end
end

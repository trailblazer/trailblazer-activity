require "test_helper"

class ActivityTest < Minitest::Spec
  module Blog
    Read     = ->(options) { options["Read"] = Trailblazer::Circuit::Right }
    NextPage = ->(options) { options["NextPage"] = Trailblazer::Circuit::Right }
    Comment  = ->(options) { options["Comment"] = Trailblazer::Circuit::Right }
  end

  # Task
  it do
    task = Trailblazer::Circuit::Task(Blog::Read, :blogread)
    task.(nil, options = {}).must_equal Trailblazer::Circuit::Right
    options.must_equal({ "Read" => Trailblazer::Circuit::Right })
    task.to_id.must_equal :blogread
  end

  it do
    process = Trailblazer::Circuit.new(:default, end: {
      default: Trailblazer::Circuit::End.new(:default),
      error:   Trailblazer::Circuit::End.new(:error),
      retry:   Trailblazer::Circuit::End.new(:retry),
    } ) do |p|
    end

    process.End.must_be_instance_of Trailblazer::Circuit::End
    process.End(:error).must_be_instance_of Trailblazer::Circuit::End
    process.End(:retry).must_be_instance_of Trailblazer::Circuit::End
    process.End(:nope).must_be_nil
    process.End.wont_equal process.End(:error)
    process.End(:retry).wont_equal process.End(:error)
  end

  # no explicit :end_events provided.
  it do
    process = Trailblazer::Circuit.new(:default) do |p|
    end

    process.End.must_be_instance_of Trailblazer::Circuit::End
    process.End(:nope).must_be_nil
  end


  # Circuit
  describe "Circuit" do
    let(:reading) { Trailblazer::Circuit.new(:reading){} }

    # SUSPEND
    it { reading.SUSPEND.inspect.must_equal %{#<Suspend: reading {:resume=>#<Resume: reading {}>}>} }
    it { reading.Suspend(more: "yes", resume: "please!").inspect.must_equal %{#<Suspend: reading {:resume=>"please!", :more=>\"yes\"}>} }
    it do
      suspend = nil
      Trailblazer::Circuit.new(:reading){ |prc| suspend = prc.Suspend(more: "yes", resume: "please!") }
      suspend.inspect.must_equal %{#<Suspend: reading {:resume=>"please!", :more=>\"yes\"}>}
    end

    # RESUME
    it { reading.Resume(instances: {1=>{ needs: "yes" }, 2=>{ needs: "too" } }).inspect.must_equal %{#<Resume: reading {:instances=>{1=>{:needs=>\"yes\"}, 2=>{:needs=>\"too\"}}}>} }
  end
end

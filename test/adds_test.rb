require "test_helper"

class AddsTest < Minitest::TrailblazerSpec
  # DISCUSS: not tested here is Append to empty Pipeline because we always initialize it.
  let(:pipeline) { Trailblazer::Activity::TaskWrap::Pipeline }
  let(:adds)     { Trailblazer::Activity::Adds }

#@ No mutation on original pipe
#@ Those tests are written in one single {it} on purpose. Further on, we perform all ADDS operations
#@ before we assert the particular pipelines to test if anything gets mutated during the way.
  it "what" do
    pipe1 = pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"]])

  #@ {Prepend} to element 0
    add = { insert: [adds::Insert.method(:Prepend), "task_wrap.call_task"], row: pipeline::Row["trace-in-outer", "trace, prepare"] }
    pipe2 = adds.apply_adds(pipe1, [add])

  #@ {Append} to element 0
    add = { insert: [adds::Insert.method(:Append), "task_wrap.call_task"], row: pipeline::Row["trace-out-outer", "trace, prepare"] }
    pipe3 = adds.apply_adds(pipe2, [add])

  #@ {Prepend} again
    add = { insert: [adds::Insert.method(:Prepend), "task_wrap.call_task"], row: pipeline::Row["trace-in-inner", "trace, prepare"] }
    pipe4 = adds.apply_adds(pipe3, [add])

  #@ {Append} again
    add = { insert: [adds::Insert.method(:Append), "task_wrap.call_task"], row: pipeline::Row["trace-out-inner", "trace, prepare"] }
    pipe5 = adds.apply_adds(pipe4, [add])

  #@ {Append} to last element
    add = { insert: [adds::Insert.method(:Append), "trace-out-outer"], row: pipeline::Row["last-id", "log"] }
    pipe6 = adds.apply_adds(pipe5, [add])

  #@ {Replace} first element
    add = { insert: [adds::Insert.method(:Replace), "trace-in-outer"], row: pipeline::Row["first-element", "log"] }
    pipe7 = adds.apply_adds(pipe6, [add])

  #@ {Replace} last element
    add = { insert: [adds::Insert.method(:Replace), "last-id"], row: pipeline::Row["last-element", "log"] }
    pipe8 = adds.apply_adds(pipe7, [add])

  #@ {Replace} middle element
    add = { insert: [adds::Insert.method(:Replace), "trace-out-outer"], row: pipeline::Row["middle-element", "log"] }
    pipe9 = adds.apply_adds(pipe8, [add])

  #@ {Delete} first element
    add = { insert: [adds::Insert.method(:Delete), "first-element"], row: nil }
    pipe10 = adds.apply_adds(pipe9, [add])

  #@ {Delete} last element
    add = { insert: [adds::Insert.method(:Delete), "last-element"], row: nil }
    pipe11 = adds.apply_adds(pipe10, [add])

  #@ {Delete} middle element
    add = { insert: [adds::Insert.method(:Delete), "trace-out-inner"], row: nil }
    pipe12 = adds.apply_adds(pipe11, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[["task_wrap.call_task", "task, call"]]>
}

    assert_equal inspect(pipe2), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"]]>
}

    assert_equal inspect(pipe3), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal inspect(pipe4), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal inspect(pipe5), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal inspect(pipe6), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal inspect(pipe7), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal inspect(pipe8), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-element", "log"]]>
}

    assert_equal inspect(pipe9), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal inspect(pipe10), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal inspect(pipe11), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"]]>
}

    assert_equal inspect(pipe12), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["middle-element", "log"]]>
}
  end

  it "{Append} without ID on empty list" do
    pipe = pipeline.new([])

    add = { insert: [adds::Insert.method(:Append)], row: pipeline::Row["laster-id", "log"] }
    pipe1 = adds.apply_adds(pipe, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[["laster-id", "log"]]>
}
  end

  let(:one_element_pipeline) { pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"]]) }

  it "{Append} on 1-element list" do
    add = { insert: [adds::Insert.method(:Append), "task_wrap.call_task"], row: pipeline::Row["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[[\"task_wrap.call_task\", \"task, call\"], [\"laster-id\", \"log\"]]>
}
  end

  it "{Replace} on 1-element list" do
    add = { insert: [adds::Insert.method(:Replace), "task_wrap.call_task"], row: pipeline::Row["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[[\"laster-id\", \"log\"]]>
}
  end

  it "{Delete} on 1-element list" do
    add = { insert: [adds::Insert.method(:Delete), "task_wrap.call_task"], row: nil }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline: @sequence=[]>
}
  end

  it "{Prepend} without ID on empty list" do
    pipe = pipeline.new([])

    add = { insert: [adds::Insert.method(:Prepend)], row: pipeline::Row["laster-id", "log"] }
    pipe1 = adds.apply_adds(pipe, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[["laster-id", "log"]]>
}
  end

    it "{Prepend} without ID on 1-element list" do
    add = { insert: [adds::Insert.method(:Prepend)], row: pipeline::Row["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[[\"laster-id\", \"log\"], [\"task_wrap.call_task\", \"task, call\"]]>
}
  end

  it "throws an Adds::Sequence error when ID non-existant" do
    pipe = pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"], pipeline::Row["task_wrap.log", "task, log"]])

  #@ {Prepend} to element that doesn't exist
    add = { insert: [adds::Insert.method(:Prepend), "NOT HERE!"], row: pipeline::Row["trace-in-outer", "trace, prepare"] }

    exception = assert_raises Activity::Adds::IndexError do
      adds.apply_adds(pipe, [add])
    end

    assert_equal exception.message, %{
\e[31m\"NOT HERE!\" is not a valid step ID. Did you mean any of these ?\e[0m
\e[32m\"task_wrap.call_task\"
\"task_wrap.log\"\e[0m}
  end

  def inspect(pipe)
    pipe.pretty_inspect.sub(/0x\w+/, "")
  end
end

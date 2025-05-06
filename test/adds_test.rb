require "test_helper"

class AddsTest < Minitest::Spec
  # DISCUSS: not tested here is Append to empty Pipeline because we always initialize it.
  let(:pipeline) { Trailblazer::Activity::TaskWrap::Pipeline }
  let(:adds)     { Trailblazer::Activity::Adds }

#@ No mutation on original pipe
#@ Those tests are written in one single {it} on purpose. Further on, we perform all ADDS operations
#@ before we assert the particular pipelines to test if anything gets mutated during the way.

  # Canonical top-level API
  it "what" do
    pipe1 = pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"]])

  #@ {Prepend} to element 0
    pipe2 = adds.(pipe1, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-outer"])

  #@ {Append} to element 0
    pipe3 = adds.(pipe2, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-outer"])

  #@ {Prepend} again
    pipe4 = adds.(pipe3, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-inner"])

  #@ {Append} again
    pipe5 = adds.(pipe4, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-inner"])

  #@ {Append} to last element
    pipe6 = adds.(pipe5, ["log", append: "trace-out-outer", id: "last-id"])

  #@ {Replace} first element
    pipe7 = adds.(pipe6, ["log", replace: "trace-in-outer", id: "first-element"])

  #@ {Replace} last element
    pipe8 = adds.(pipe7, ["log", replace: "last-id", id: "last-element"])

  #@ {Replace} middle element
    pipe9 = adds.(pipe8, ["log", replace: "trace-out-outer", id: "middle-element"])

  #@ {Delete} first element
    pipe10 = adds.(pipe9, ["log", delete: "first-element", id: nil])

  #@ {Delete} last element
    pipe11 = adds.(pipe10, ["log", delete: "last-element", id: nil])

  #@ {Delete} middle element
    pipe12 = adds.(pipe11, [nil, delete: "trace-out-inner", id: nil])

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

  # Internal API, currently used in dsl, too.
  it "what" do
    pipe1 = pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"]])

  #@ {Prepend} to element 0
    pipe2 = adds.(pipe1, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-outer"])

  #@ {Append} to element 0
    pipe3 = adds.(pipe2, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-outer"])

  #@ {Prepend} again
    pipe4 = adds.(pipe3, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-inner"])

  #@ {Append} again
    pipe5 = adds.(pipe4, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-inner"])

  #@ {Append} to last element
    pipe6 = adds.(pipe5, ["log", append: "trace-out-outer", id: "last-id"])

  #@ {Replace} first element
    pipe7 = adds.(pipe6, ["log", replace: "trace-in-outer", id: "first-element"])

  #@ {Replace} last element
    pipe8 = adds.(pipe7, ["log", replace: "last-id", id: "last-element"])

  #@ {Replace} middle element
    pipe9 = adds.(pipe8, ["log", replace: "trace-out-outer", id: "middle-element"])

  #@ {Delete} first element
    pipe10 = adds.(pipe9, ["log", delete: "first-element", id: nil])

  #@ {Delete} last element
    pipe11 = adds.(pipe10, ["log", delete: "last-element", id: nil])

  #@ {Delete} middle element
    pipe12 = adds.(pipe11, [nil, delete: "trace-out-inner", id: nil])

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

  it "{.call} allows passing a {:row} option per instruction" do
    pipe1 = pipeline.new([pipeline::Row["task_wrap.call_task", "task, call"]])
    my_row_class = Class.new(Array) do
      def id
        "my id"
      end
    end

    pipe2 = adds.(pipeline.new([]), [nil, prepend: nil, id: "task_wrap.call_task", row: my_row_class[1,2,3]])

    assert_equal pipe2.to_a.collect { |row| row.class }, [my_row_class]
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

    exception = assert_raises Trailblazer::Activity::Adds::IndexError do
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

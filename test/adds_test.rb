require "test_helper"

class PipelineTest < Minitest::Spec
  it "provides .Pipeline that receives a hash" do
    pipe = Trailblazer::Activity::Pipeline("a" => 1, "b" => 2)

    assert_equal pipe.to_a.inspect, %([["a", 1], ["b", 2]])
  end

  it "provides #find(id:)" do
    pipe = Trailblazer::Activity::Pipeline("a" => 1, "b" => Object)

    assert_equal Trailblazer::Activity::Pipeline.find(pipe, id: "b"), Object
    assert_equal Trailblazer::Activity::Pipeline.find(pipe, id: nil).inspect, %(nil)
  end
end

class AddsTest < Minitest::Spec
  # DISCUSS: not tested here is Append to empty Pipeline because we always initialize it.
  let(:adds)     { Trailblazer::Activity::Adds }

#@ No mutation on original pipe
#@ Those tests are written in one single {it} on purpose. Further on, we perform all ADDS operations
#@ before we assert the particular pipelines to test if anything gets mutated during the way.

  # Canonical top-level API
  it "what" do
    pipe1 = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]])

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

    assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=[["task_wrap.call_task", "task, call"]]>
}

    assert_equal CU.strip(pipe2.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"]]>
}

    assert_equal CU.strip(pipe3.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe4.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe5.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe6.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal CU.strip(pipe7.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal CU.strip(pipe8.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe9.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe10.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe11.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"]]>
}

    assert_equal CU.strip(pipe12.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["middle-element", "log"]]>
}
  end

  # Internal API, currently used in dsl, too.
  it "what" do
    pipe1 = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]])

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

    assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=[["task_wrap.call_task", "task, call"]]>
}

    assert_equal CU.strip(pipe2.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"]]>
}

    assert_equal CU.strip(pipe3.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe4.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe5.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"]]>
}

    assert_equal CU.strip(pipe6.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-outer", "trace, prepare"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal CU.strip(pipe7.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-id", "log"]]>
}

    assert_equal CU.strip(pipe8.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["trace-out-outer", "trace, prepare"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe9.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["first-element", "log"],
   ["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe10.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"],
   ["last-element", "log"]]>
}

    assert_equal CU.strip(pipe11.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["trace-out-inner", "trace, prepare"],
   ["middle-element", "log"]]>
}

    assert_equal CU.strip(pipe12.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=
  [["trace-in-inner", "trace, prepare"],
   ["task_wrap.call_task", "task, call"],
   ["middle-element", "log"]]>
}
  end

  it "raises when {:id} is omitted" do
    exception = assert_raises do
      pipe1 = adds.(Trailblazer::Activity::Pipeline.new([]), [Object, prepend: nil])
    end

    assert_equal exception.message.gsub(":", ""), %(missing keyword id)
  end

  it "{Append} without ID on empty list" do
    pipe = Trailblazer::Activity::Pipeline.new([])

    add = { insert: [adds::Insert.method(:Append)], row: ["laster-id", "log"] }
    pipe1 = adds.apply_adds(pipe, [add])

    assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[["laster-id", "log"]]>}
  end

  let(:one_element_pipeline) { Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]]) }

  it "{Append} on 1-element list" do
    add = { insert: [adds::Insert.method(:Append), "task_wrap.call_task"], row: ["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[[\"task_wrap.call_task\", \"task, call\"], [\"laster-id\", \"log\"]]>}
  end

  it "{Replace} on 1-element list" do
    add = { insert: [adds::Insert.method(:Replace), "task_wrap.call_task"], row: ["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[[\"laster-id\", \"log\"]]>}
  end

  it "{Delete} on 1-element list" do
    add = { insert: [adds::Insert.method(:Delete), "task_wrap.call_task"], row: nil }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[]>
}
  end

  it "{Prepend} without ID on empty list" do
    pipe = Trailblazer::Activity::Pipeline.new([])

    add = { insert: [adds::Insert.method(:Prepend)], row: ["laster-id", "log"] }
    pipe1 = adds.apply_adds(pipe, [add])

    assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[["laster-id", "log"]]>}
  end

    it "{Prepend} without ID on 1-element list" do
    add = { insert: [adds::Insert.method(:Prepend)], row: ["laster-id", "log"] }
    pipe1 = adds.apply_adds(one_element_pipeline, [add])

    assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
 @sequence=[[\"laster-id\", \"log\"], [\"task_wrap.call_task\", \"task, call\"]]>
}
  end

  it "throws an Adds::Sequence error when ID non-existant" do
    pipe = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"], ["task_wrap.log", "task, log"]])

  #@ {Prepend} to element that doesn't exist
    add = { insert: [adds::Insert.method(:Prepend), "NOT HERE!"], row: ["trace-in-outer", "trace, prepare"] }

    exception = assert_raises Trailblazer::Activity::Adds::IndexError do
      adds.apply_adds(pipe, [add])
    end

    assert_equal exception.message, %{
\e[31m\"NOT HERE!\" is not a valid step ID. Did you mean any of these ?\e[0m
\e[32m\"task_wrap.call_task\"
\"task_wrap.log\"\e[0m}
  end
end


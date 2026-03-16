require "test_helper"

class CircuitAddsTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, :d, :e, :z, :y) }

  let(:model_tw_pipe) do
    Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:a, :a, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],
      [:b, :b, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],
      [:c, :c, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],
    )
  end

  let(:node_options) { {interface: Trailblazer::Activity::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}} }

  after do
    # No mutation on original circuit.
    assert_run model_tw_pipe, seq: [:a, :b, :c], terminus: Trailblazer::Activity::Right # def_tasks return Right.
    # TODO: maybe we should test internal properties here, to make sure config isn't altered etc.
  end

  # FIXME: private test
  it "prepare_insertion" do
    flow_map, _, _, config = model_tw_pipe.to_a

    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, nil, index_for_nil: 0)# before: nil
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :a, index_for_nil: 0)# before: :a
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :b, index_for_nil: 0)# before: :b
    assert_equal [target_id, target_index], [:b, 1]

    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, nil, index_for_nil: -1, offset: 1)# after: nil
    assert_equal [target_id, target_index], [:c, -1]
    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :c, index_for_nil: -1, offset: 1)# after: :c
    assert_equal [target_id, target_index], [:c, 3]
    _, target_id, target_index = Trailblazer::Activity::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :a, index_for_nil: -1, offset: 1)# after: :a
    assert_equal [target_id, target_index], [:a, 1]
  end

  it "{before, nil, before, nil} adds to the beginning, the last becomes the first" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :before],
      [_A::Circuit::Node::Scoped[id: :y, task: :y, **node_options], :before],
    )

    assert_run extended_tw_pipe, seq: [:y, :z, :a, :b, :c], terminus: Trailblazer::Activity::Right
  end

  it "{before, :b}" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :before, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :b, :c], terminus: Trailblazer::Activity::Right
  end

  it "{after, :b}" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z, :c], terminus: Trailblazer::Activity::Right
  end

  it "{after, :b}, {after: :b}" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :after, :b],
      [_A::Circuit::Node::Scoped[id: :y, task: :y, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :y, :z, :c], terminus: Trailblazer::Activity::Right
  end

  it "{after, nil}, {after: nil}" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :after],
      [_A::Circuit::Node::Scoped[id: :y, task: :y, **node_options], :after],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :c, :z, :y], terminus: Trailblazer::Activity::Right
  end

  it ":delete, first node" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :delete, :a],
    )

    assert_run extended_tw_pipe, seq: [:b, :c], terminus: Trailblazer::Activity::Right
  end

  it ":delete middle" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :delete, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :c], terminus: Trailblazer::Activity::Right
  end

  it ":delete, last" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :delete, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b], terminus: Trailblazer::Activity::Right
  end

  it ":replace first" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :replace, :a],
    )

    assert_run extended_tw_pipe, seq: [:z, :b, :c], terminus: Trailblazer::Activity::Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:z, :b, :c] # TODO: do that everywhere!
  end

  it ":replace middle" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :replace, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :c], terminus: Trailblazer::Activity::Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :z, :c] # TODO: do that everywhere!
  end

  it ":replace last" do
    extended_tw_pipe = Trailblazer::Activity::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[id: :z, task: :z, **node_options], :replace, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z], terminus: Trailblazer::Activity::Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :b, :z] # TODO: do that everywhere!
  end

  it "can extend Circuit, too" do
    skip

  end
end

# class AddsTest < Minitest::Spec
#   # DISCUSS: not tested here is Append to empty Pipeline because we always initialize it.
#   let(:adds)     { Trailblazer::Activity::Adds }

# #@ No mutation on original pipe
# #@ Those tests are written in one single {it} on purpose. Further on, we perform all ADDS operations
# #@ before we assert the particular pipelines to test if anything gets mutated during the way.

#   # Canonical top-level API
#   it "what" do
#     pipe1 = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]])

#   #@ {Prepend} to element 0
#     pipe2 = adds.(pipe1, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-outer"])

#   #@ {Append} to element 0
#     pipe3 = adds.(pipe2, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-outer"])

#   #@ {Prepend} again
#     pipe4 = adds.(pipe3, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-inner"])

#   #@ {Append} again
#     pipe5 = adds.(pipe4, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-inner"])

#   #@ {Append} to last element
#     pipe6 = adds.(pipe5, ["log", append: "trace-out-outer", id: "last-id"])

#   #@ {Replace} first element
#     pipe7 = adds.(pipe6, ["log", replace: "trace-in-outer", id: "first-element"])

#   #@ {Replace} last element
#     pipe8 = adds.(pipe7, ["log", replace: "last-id", id: "last-element"])

#   #@ {Replace} middle element
#     pipe9 = adds.(pipe8, ["log", replace: "trace-out-outer", id: "middle-element"])

#   #@ {Delete} first element
#     pipe10 = adds.(pipe9, ["log", delete: "first-element", id: nil])

#   #@ {Delete} last element
#     pipe11 = adds.(pipe10, ["log", delete: "last-element", id: nil])

#   #@ {Delete} middle element
#     pipe12 = adds.(pipe11, [nil, delete: "trace-out-inner", id: nil])

#     assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=[["task_wrap.call_task", "task, call"]]>
# }

#     assert_equal CU.strip(pipe2.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"]]>
# }

#     assert_equal CU.strip(pipe3.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe4.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe5.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe6.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-id", "log"]]>
# }

#     assert_equal CU.strip(pipe7.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-id", "log"]]>
# }

#     assert_equal CU.strip(pipe8.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe9.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe10.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe11.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"]]>
# }

#     assert_equal CU.strip(pipe12.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["middle-element", "log"]]>
# }
#   end

#   # Internal API, currently used in dsl, too.
#   it "what" do
#     pipe1 = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]])

#   #@ {Prepend} to element 0
#     pipe2 = adds.(pipe1, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-outer"])

#   #@ {Append} to element 0
#     pipe3 = adds.(pipe2, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-outer"])

#   #@ {Prepend} again
#     pipe4 = adds.(pipe3, ["trace, prepare", prepend: "task_wrap.call_task", id: "trace-in-inner"])

#   #@ {Append} again
#     pipe5 = adds.(pipe4, ["trace, prepare", append: "task_wrap.call_task", id: "trace-out-inner"])

#   #@ {Append} to last element
#     pipe6 = adds.(pipe5, ["log", append: "trace-out-outer", id: "last-id"])

#   #@ {Replace} first element
#     pipe7 = adds.(pipe6, ["log", replace: "trace-in-outer", id: "first-element"])

#   #@ {Replace} last element
#     pipe8 = adds.(pipe7, ["log", replace: "last-id", id: "last-element"])

#   #@ {Replace} middle element
#     pipe9 = adds.(pipe8, ["log", replace: "trace-out-outer", id: "middle-element"])

#   #@ {Delete} first element
#     pipe10 = adds.(pipe9, ["log", delete: "first-element", id: nil])

#   #@ {Delete} last element
#     pipe11 = adds.(pipe10, ["log", delete: "last-element", id: nil])

#   #@ {Delete} middle element
#     pipe12 = adds.(pipe11, [nil, delete: "trace-out-inner", id: nil])

#     assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=[["task_wrap.call_task", "task, call"]]>
# }

#     assert_equal CU.strip(pipe2.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"]]>
# }

#     assert_equal CU.strip(pipe3.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe4.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe5.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"]]>
# }

#     assert_equal CU.strip(pipe6.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-outer", "trace, prepare"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-id", "log"]]>
# }

#     assert_equal CU.strip(pipe7.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-id", "log"]]>
# }

#     assert_equal CU.strip(pipe8.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["trace-out-outer", "trace, prepare"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe9.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["first-element", "log"],
#    ["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe10.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"],
#    ["last-element", "log"]]>
# }

#     assert_equal CU.strip(pipe11.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["trace-out-inner", "trace, prepare"],
#    ["middle-element", "log"]]>
# }

#     assert_equal CU.strip(pipe12.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=
#   [["trace-in-inner", "trace, prepare"],
#    ["task_wrap.call_task", "task, call"],
#    ["middle-element", "log"]]>
# }
#   end

#   it "raises when {:id} is omitted" do
#     exception = assert_raises do
#       adds.(Trailblazer::Activity::Pipeline.new([]), [Object, prepend: nil])
#     end

#     assert_equal exception.message.gsub(":", ""), %(missing keyword id)
#   end

#   it "{Append} without ID on empty list" do
#     pipe = Trailblazer::Activity::Pipeline.new([])

#     add = { insert: [adds::Insert.method(:Append)], row: ["laster-id", "log"] }
#     pipe1 = adds.apply_adds(pipe, [add])

#     assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[["laster-id", "log"]]>}
#   end

#   let(:one_element_pipeline) { Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"]]) }

#   it "{Append} on 1-element list" do
#     add = { insert: [adds::Insert.method(:Append), "task_wrap.call_task"], row: ["laster-id", "log"] }
#     pipe1 = adds.apply_adds(one_element_pipeline, [add])

#     assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[[\"task_wrap.call_task\", \"task, call\"], [\"laster-id\", \"log\"]]>}
#   end

#   it "{Replace} on 1-element list" do
#     add = { insert: [adds::Insert.method(:Replace), "task_wrap.call_task"], row: ["laster-id", "log"] }
#     pipe1 = adds.apply_adds(one_element_pipeline, [add])

#     assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[[\"laster-id\", \"log\"]]>}
#   end

#   it "{Delete} on 1-element list" do
#     add = { insert: [adds::Insert.method(:Delete), "task_wrap.call_task"], row: nil }
#     pipe1 = adds.apply_adds(one_element_pipeline, [add])

#     assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[]>
# }
#   end

#   it "{Prepend} without ID on empty list" do
#     pipe = Trailblazer::Activity::Pipeline.new([])

#     add = { insert: [adds::Insert.method(:Prepend)], row: ["laster-id", "log"] }
#     pipe1 = adds.apply_adds(pipe, [add])

#     assert_equal CU.strip(pipe1.inspect), %{#<Trailblazer::Activity::Pipeline:0x @sequence=[["laster-id", "log"]]>}
#   end

#     it "{Prepend} without ID on 1-element list" do
#     add = { insert: [adds::Insert.method(:Prepend)], row: ["laster-id", "log"] }
#     pipe1 = adds.apply_adds(one_element_pipeline, [add])

#     assert_equal CU.strip(pipe1.pretty_inspect), %{#<Trailblazer::Activity::Pipeline:0x
#  @sequence=[[\"laster-id\", \"log\"], [\"task_wrap.call_task\", \"task, call\"]]>
# }
#   end

#   it "throws an Adds::Sequence error when ID non-existant" do
#     pipe = Trailblazer::Activity::Pipeline.new([["task_wrap.call_task", "task, call"], ["task_wrap.log", "task, log"]])

#   #@ {Prepend} to element that doesn't exist
#     add = { insert: [adds::Insert.method(:Prepend), "NOT HERE!"], row: ["trace-in-outer", "trace, prepare"] }

#     exception = assert_raises Trailblazer::Activity::Adds::IndexError do
#       adds.apply_adds(pipe, [add])
#     end

#     assert_equal exception.message, %{
# \e[31m\"NOT HERE!\" is not a valid step ID. Did you mean any of these ?\e[0m
# \e[32m\"task_wrap.call_task\"
# \"task_wrap.log\"\e[0m}
#   end
# end


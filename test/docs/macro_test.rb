require "test_helper"

class DocsMacroTest < Minitest::Spec
  describe "using a block" do
    let(:activity) do
      Module.new do
        extend Activity::Path()

        module_function
        def self.MyNested(target: "mine", &block)
          task = ->((ctx, flow_options), *) do
            ctx[:my_nested] = yield(target) # use the block.

            return Trailblazer::Activity::Right, [ctx, flow_options]
          end

          { task: task }
        end

        pass MyNested(target: "yours") { |target|
          "this block's content is all #{target}!"
        }
      end
    end

    it "allows to claim and call the block that would usually go to the DSL" do
      end_event, (ctx, _) = activity.( [{}] )
      ctx.must_equal(:my_nested=>"this block's content is all yours!")
    end
  end

  let(:branching) do
    content = %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<TaskBuilder{.find_model}>
#<TaskBuilder{.find_model}>
 {Trailblazer::Activity::Left} => #<TaskBuilder{.create}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{.update}>
#<TaskBuilder{.create}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{.save}>
#<TaskBuilder{.update}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{.save}>
#<TaskBuilder{.save}>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  describe "manual branching" do
    let(:activity) do
      Module.new do
        extend Activity::Path()

        module_function
        def find_model(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def create(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def update(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def save(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end

        task method(:find_model), Output(Activity::Left, :failure) => "create", Output(:success) => "update"
        task method(:create), magnetic_to: [], id: "create"
        task method(:update), magnetic_to: [], id: "update"
        task method(:save)
      end
    end


    it "creates correct activity" do
      Cct(activity.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder) ).must_equal branching
    end
  end

  describe "If()" do
    let(:activity) do
      Module.new do
        extend Activity::Path()

        module_function
        def find_model(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def create(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def update(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end
        def save(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end

        task method(:find_model),
          Output(:failure) => task(method(:create)),
          Output(:success) => task(method(:update))

        task method(:save)
      end
    end

    it "creates correct activity" do
      skip "think about me"
      Cct(activity.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder) ).must_equal branching
    end
  end
end

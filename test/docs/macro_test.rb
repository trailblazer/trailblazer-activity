require "test_helper"

class DocsMacroTest < Minitest::Spec
  let(:branching) do
    content = %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.find_model>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.find_model>}>
 {Trailblazer::Activity::Left} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.create>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.update>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.create>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.save>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.update>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.save>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {}>.save>}>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    content = content.gsub("#<Trailblazer::Activity: {}>.", "#<Method: #<Module:0x>.") if RUBY_PLATFORM == "java"
    content
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

        task method(:find_model), Output(:failure) => "create", Output(:success) => "update"
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
      Cct(activity.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder) ).must_equal branching
    end
  end
end

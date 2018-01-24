require "test_helper"

class DocsActivityTest < Minitest::Spec
  Memo = Struct.new(:body) do
    def self.find_by(*)
      Memo.new
    end

    def update_attributes(*)

    end
  end

  describe "#what" do
    it do
        module Update
          extend Trailblazer::Activity::Railway()
          module_function

          # here goes your business logic
          #
          def find_model(ctx, id:, **)
            ctx[:model] = Memo.find_by(id: id)
          end

          def validate(ctx, params:, **)
            return true if params[:body].is_a?(String) && params[:body].size > 10
            ctx[:errors] = "body not long enough"
            false
          end

          def save(ctx, model:, params:, **)
            model.update_attributes(params)
          end

          def log_error(ctx, params:, **)
            ctx[:log] = "Some idiot wrote #{params.inspect}"
          end

          # here comes the DSL describing the layout of the activity
          #
          step method(:find_model)
          step method(:validate), Output(:failure) => End(:validation_error)
          step method(:save)
          fail method(:log_error)
        end

      ctx = { id: 1, params: { body: "Awesome!" } }

      event, (ctx, *) = Update.( [ctx, {}] )

      pp ctx
      pp event
    end
  end
end

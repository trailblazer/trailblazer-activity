require "test_helper"

class ActivityOptionTest < Minitest::Spec
  def my_output(ctx, params:, **)
    {
      id: params[:id],
    }
  end

  def my_output_with_circuit_interface(ctx, flow_options, circuit_options)
    value = {
      id:           ctx[:params][:id],
      exec_context: circuit_options[:exec_context],
    }

    return ctx, flow_options, value
  end

  let(:ctx) { {params: {id: 1}, action: :update} }
  let(:circuit_options){ {exec_context: self, wrap_runtime: {}} }

  describe "Option::InstanceMethod" do
    it "can run a method with step interface" do
      # instance method with step interface
      option = Trailblazer::Activity::Option::InstanceMethod.new(:my_output)

      value = option.(self.ctx, keyword_arguments: self.ctx.to_hash, **circuit_options)

      assert_equal value, {id: 1}
    end

    it "can run an instance method with a circuit interface, too" do
      # instance method with different interface, for example, circuit interface (how surprising!)
      option = Trailblazer::Activity::Option::InstanceMethod.new(:my_output_with_circuit_interface)

      ctx, flow_options, value = option.(self.ctx, flow_options, circuit_options, **circuit_options) # DISCUSS: omitting {:keyword_arguments} might lead to problems in Ruby < 2.7.

      assert_equal value, {id: 1, exec_context: self}
      assert_equal ctx, self.ctx
    end

    it "can run instance method with circuit interface and {:keyword_arguments}" do
      def my_handler_with_circuit_interface_and_kwargs(ctx, flow_options, circuit_options, exception:, **options)
        return ctx, flow_options, {exception: exception, ctx_inspect: CU.inspect(ctx)}
      end

      option = Trailblazer::Activity::Option::InstanceMethod.new(:my_handler_with_circuit_interface_and_kwargs)

      ctx, flow_options, value = option.(self.ctx, flow_options, circuit_options, **circuit_options, keyword_arguments: {exception: 1}) # DISCUSS: omitting {:keyword_arguments} might lead to problems in Ruby < 2.7.

      assert_equal value, {:exception=>1, :ctx_inspect=>"{:params=>{:id=>1}, :action=>:update}"}
      assert_equal ctx, self.ctx
    end
  end
end

require "test_helper"

class DocsOutputToIdTest < Minitest::Spec
  class CustomTest < Minitest::Spec
    module User
    end

    it do
      #:track-ref
      module User::Signin
        extend Trailblazer::Activity::Railway()
        # ~methods
        extend T.def_steps(:sign_in, :create)
        def self.find_by_omniauth(ctx, **)
          ctx[:seq] << :find_by_omniauth
          ctx[:find_by_omniauth_return]
        end

        def self.find_by_email(ctx, **)
          ctx[:seq] << :find_by_email
          ctx[:find_by_email_return]
        end
        # ~methods end
        step method(:find_by_omniauth)
        fail method(:find_by_email), Output(:success) => Track(:success)
        step method(:sign_in)
        fail method(:create)
      end
      #:track-ref end

      # Cct(User::Signin.to_h[:circuit]).must_equal %{
      # }

      # user known by Omniauth
      signal, (ctx,) = User::Signin.([{seq: [], find_by_omniauth_return: true}])
      _(ctx).must_equal({:seq => %i[find_by_omniauth sign_in], :find_by_omniauth_return => true})

      # user known via email
      signal, (ctx,) = User::Signin.([{seq: [], find_by_omniauth_return: false, find_by_email_return: true}])
      _(ctx).must_equal({:seq => %i[find_by_omniauth find_by_email sign_in], :find_by_omniauth_return => false, :find_by_email_return => true})

      # user unknown
      signal, (ctx,) = User::Signin.([{seq: [], find_by_omniauth_return: false, find_by_email_return: false}])
      _(ctx).must_equal({:seq => %i[find_by_omniauth find_by_email create], :find_by_omniauth_return => false, :find_by_email_return => false})
    end
  end
end

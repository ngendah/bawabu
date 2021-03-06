require 'locale'
require 'token_generator'


module Tokens
  module Type
    class Base
      include Locale

      def token(auth_params, options = {})
        raise NotImplementedError
      end

      def is_valid(auth_params)
        case auth_params.action
        when :show.to_s
          errors = token_validate auth_params
        when :update.to_s
          errors = refresh_validate auth_params
        when :destroy.to_s
          errors = revoke_validate auth_params
        else
          raise StandardError, 'Invalid action'
        end
        errors
      end

      def refresh(auth_params, options = {})
        raise NotImplementedError
      end

      def revoke(auth_params, options = {})
        ::AccessToken.revoke auth_params.access_token
      end

      def type_name
        raise NotImplementedError
      end

      def query(auth_params)
        access_token = ::AccessToken.find_by_token auth_params.access_token
        introspection = { active: false }
        unless access_token.nil? || access_token.invalid?
          introspection = {
            expires_in: access_token.expires,
            active: !access_token.expired?,
            grant_type: access_token.grant_type,
            scope: access_token.scopes,
            token_type: access_token.refresh ? 'refresh' : 'access'
          }
          introspection = token_time_to_timedelta introspection
        end
        introspection
      end

      protected

      # convert token expiry period to number of seconds from now
      #
      # An oauth2 client would like to know how long a given token would be valid.
      # However, this delta has a side-effect of also being misleading.
      # Since it does not account for request trip time, for large time deltas, it would be
      # acceptable but for small time deltas it would be downright wrong
      #
      def token_time_to_timedelta(token)
        token[:expires_in] = timedelta_from_now token[:expires_in]
        token
      end

      # validate a token request
      #
      # subclasses are expected to implement this method validating the request
      # parameters and returning a list which is either empty or with all the errors
      # encountered
      #
      def token_validate(auth_params)
        raise NotImplementedError
      end

      # validate a refresh token request
      #
      # subclasses are expected to implement this method validating the request
      # parameters and returning a list which is either empty or with all the errors
      # encountered
      #
      def refresh_validate(auth_params)
        raise NotImplementedError
      end

      # validate a token revocation request
      #
      def revoke_validate(auth_params)
        errors = []
        begin
          bearer_token = ::AccessToken.find_by_token auth_params.bearer_token
          if bearer_token.nil? || bearer_token.invalid?
            errors.append user_err(:bearer_token_invalid)
          elsif bearer_token.refresh
            errors.append user_err(:bearer_token_is_refresh)
          end
          token = ::AccessToken.find_by_token auth_params.access_token
          errors.append(user_err(:token_invalid)) if token.nil?
        rescue StandardError => error
          errors.append user_err(:bad_auth_header)
        end
        errors
      end

      def timedelta_from_now(to)
        to.tv_sec - Time.now.tv_sec
      end

      # create an access token given a model object instance and options
      #
      # the model object instance should have a one-to-many relation to
      # access_token model
      #
      # options can be, a correlation uid and a token expiry period
      #
      # correlation uid's are used to track tokens generated for a client
      #
      def access_token(model_object, options)
        model_object.delete_expired_tokens
        token = model_object.token
        if token.nil? || token.invalid?
          token = TokenGenerator.token
          correlation_uid = options.fetch :correlation_uid, SecureRandom.uuid
          model_object.access_tokens << ::AccessToken.create(
            token: token[:access_token], expires: token[:expires_in],
            correlation_uid: correlation_uid, grant_type: type_name)
        else
          token = {access_token: token.token, expires_in: token.expires}
        end
        token[:scope] = []
        token_time_to_timedelta token
      end

      # create a refresh token given a model object instance and options
      #
      # the model object instance should have a one-to-many relation to
      # access_token model
      #
      # options can be, a correlation uid and a token expiry period
      #
      # correlation uid's are used to track tokens generated for a client
      #
      def refresh_token(model_object, options)
        refresh_token = model_object.refresh_token
        unless refresh_token.nil? || refresh_token.invalid?
          refresh_token.revoke
        end
        expires_in = options.fetch :expires_in, 20.minutes
        correlation_uid = options.fetch :correlation_uid, nil
        refresh_token = TokenGenerator.token :default, timedelta: expires_in
        model_object.access_tokens << ::AccessToken.create(
          token: refresh_token[:access_token], refresh: true,
          expires: refresh_token[:expires_in], grant_type: type_name,
          correlation_uid: correlation_uid
        )
        token_time_to_timedelta refresh_token
      end
    end
  end
end

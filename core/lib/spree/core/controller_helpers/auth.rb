# frozen_string_literal: true

require 'cancan'

module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern

        included do
          before_action :set_token
          helper_method :try_spree_current_user

          class_attribute :unauthorized_redirect
          self.unauthorized_redirect = -> do
            flash[:error] = I18n.t('spree.authorization_failure')
            redirect_to "/unauthorized"
          end

          rescue_from CanCan::AccessDenied do
            instance_exec(&unauthorized_redirect)
          end
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Dependencies.ability_class.constantize.new(try_spree_current_user)
        end

        def redirect_back_or_default(default)
          redirect_to(session['spree_user_return_to'] || default)
          session['spree_user_return_to'] = nil
        end

        def set_token
          cookies.permanent.signed[:token] ||= cookies.signed[:guest_token]
          cookies.permanent.signed[:token] ||= {
            value: SecureRandom.urlsafe_base64(nil, false),
            httponly: true
          }
          cookies.permanent.signed[:guest_token] ||= cookies.permanent.signed[:token]            
        end

        def current_oauth_token
          user = try_spree_current_user
          return unless user

          @current_oauth_token ||= Doorkeeper::AccessToken.active_for(user).last || Doorkeeper::AccessToken.create!(resource_owner_id: user.id)
        end

        def store_location
          # disallow return to login, logout, signup pages
          authentication_routes = [:spree_signup_path, :spree_login_path, :spree_logout_path]
          disallowed_urls = []
          authentication_routes.each do |route|
            if respond_to?(route)
              disallowed_urls << send(route)
            end
          end

          disallowed_urls.map! { |url| url[/\/\w+$/] }
          unless disallowed_urls.include?(request.fullpath)
            session['spree_user_return_to'] = request.fullpath.gsub('//', '/')
          end
        end

        # proxy method to *possible* spree_current_user method
        # Authentication extensions (such as spree_auth_devise) are meant to provide spree_current_user
        def try_spree_current_user
          # This one will be defined by apps looking to hook into Spree
          # As per authentication_helpers.rb
          if respond_to?(:spree_current_user, true)
            spree_current_user
          # This one will be defined by Devise
          elsif respond_to?(:current_spree_user, true)
            current_spree_user
          end
        end
      end
    end
  end
end
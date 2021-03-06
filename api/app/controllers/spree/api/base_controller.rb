# frozen_string_literal: true

require 'spree/api/responders'

module Spree
  module Api
    class BaseController < ActionController::Base
      protect_from_forgery unless: -> { request.format.json? || request.format.xml? }
      self.responder = Spree::Api::Responders::AppResponder
      respond_to :json
      protect_from_forgery unless: -> { request.format.json? }

      include CanCan::ControllerAdditions
      include Spree::Core::ControllerHelpers::Store
      include Spree::Core::ControllerHelpers::Pricing
      include Spree::Core::ControllerHelpers::StrongParameters

      attr_accessor :current_api_user

      before_action :load_user
      before_action :authorize_for_order, if: proc { order_token.present? }
      before_action :authenticate_user
      before_action :load_user_roles

      rescue_from ActionController::ParameterMissing, with: :parameter_missing_error
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from CanCan::AccessDenied, with: :unauthorized
      rescue_from Spree::Core::GatewayError, with: :gateway_error

      helper Spree::Api::ApiHelpers

      private

      # users should be able to set price when importing orders via api
      def permitted_line_item_attributes
        if can?(:admin, Spree::LineItem)
          super + admin_line_item_attributes
        else
          super
        end
      end

      def load_user
        @current_api_user = Spree.user_class.find_by(spree_api_key: api_key.to_s)
      end

      def authenticate_user
        unless @current_api_user
          if requires_authentication? && api_key.blank? && order_token.blank?
            render "spree/api/errors/must_specify_api_key", status: 401
          elsif order_token.blank? && (requires_authentication? || api_key.present?)
            render "spree/api/errors/invalid_api_key", status: 401
          end
        end
      end

      def load_user_roles
        @current_user_roles = @current_api_user ? @current_api_user.spree_roles.pluck(:name) : []
      end

      def unauthorized
        render 'spree/api/errors/unauthorized', status: 401
      end

      def gateway_error(exception)
        @order.errors.add(:base, exception.message)
        invalid_resource!(@order)
      end

      def parameter_missing_error(exception)
        render json: {
          exception: exception.message,
          error: exception.message,
          missing_param: exception.param
        }, status: 422
      end

      def requires_authentication?
        Spree::Api::Config[:requires_authentication]
      end

      def not_found
        render 'spree/api/errors/not_found', status: 404
      end

      def current_ability
        Spree::Dependencies.ability_class.constantize.new(current_api_user)
      end

      def invalid_resource!(resource)
        Rails.logger.error "invalid_resouce_errors=#{resource.errors.full_messages}"
        @resource = resource
        render 'spree/api/errors/invalid_resource', status: 422
      end

      def api_key
        bearer_token || params[:token]
      end
      helper_method :api_key

      def bearer_token
        pattern = /^Bearer /
        header = request.headers["Authorization"]
        header.gsub(pattern, '') if header.present? && header.match(pattern)
      end

      def order_token
        request.headers['X-Spree-Order-Token'] || params[:order_token]
      end

      def find_product(id)
        product_scope.friendly.find(id.to_s)
      rescue ActiveRecord::RecordNotFound
        product_scope.find(id)
      end

      def product_scope
        if can?(:admin, Spree::Product)
          scope = Spree::Product.with_deleted.accessible_by(current_ability, :read).includes(*product_includes)

          scope = scope.not_deleted unless params[:show_deleted]
          scope = scope.not_discontinued unless params[:show_discontinued]
        else
          scope = Spree::Product.accessible_by(current_ability, :read).available.includes(*product_includes)
        end

        scope
      end

      def variants_associations
        [{ option_values: :option_type }, :default_price, :images]
      end

      def product_includes
        [:option_types, :taxons, product_properties: :property, variants: variants_associations, master: variants_associations]
      end

      def order_id
        params[:order_id] || params[:checkout_id] || params[:order_number]
      end

      def authorize_for_order
        @order = Spree::Order.find_by(number: order_id)
        authorize! :read, @order, order_token
      end

      def lock_order
        OrderMutex.with_lock!(@order) { yield }
      rescue Spree::OrderMutex::LockFailed => e
        render plain: e.message, status: 409
      end

      def insufficient_stock_error(exception)
        logger.error "insufficient_stock_error #{exception.inspect}"
        render(
          json: {
            errors: [I18n.t(:quantity_is_not_available, scope: "spree.api.order")],
            type: 'insufficient_stock'
          },
          status: 422
        )
      end

      def paginate(resource)
        resource.
          page(params[:page]).
          per(params[:per_page] || default_per_page)
      end

      def default_per_page
        Kaminari.config.default_per_page
      end
    end
  end
end
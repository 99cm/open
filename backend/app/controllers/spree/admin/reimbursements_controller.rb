# frozen_string_literal: true

module Spree
  module Admin
    class ReimbursementsController < ResourceController
      helper 'spree/admin/reimbursement_type'
      helper 'spree/admin/customer_returns'
      belongs_to 'spree/order', find_by: :number

      before_action :load_stock_locations, only: :edit
      before_action :load_simulated_refunds, only: :edit
      create.after :recalculate_order

      rescue_from Spree::Core::GatewayError, with: :spree_core_gateway_error

      def perform
        @reimbursement.perform!
        redirect_to location_after_save
      end

      private

      def recalculate_order
        @reimbursement.order.recalculate
      end

      def build_resource
        if params[:build_from_customer_return_id].present?
          customer_return = CustomerReturn.find(params[:build_from_customer_return_id])

          Spree::Reimbursement.build_from_customer_return(customer_return)
        else
          super
        end
      end

      def location_after_save
        if @reimbursement.reimbursed?
          admin_order_reimbursement_path(parent, @reimbursement)
        else
          edit_admin_order_reimbursement_path(parent, @reimbursement)
        end
      end

      def render_after_create_error
        flash.keep
        if request.referer
          redirect_to request.referer
        else
          redirect_to admin_url
        end
      end

      def load_stock_locations
        @stock_locations = Spree::StockLocation.active
      end

      def load_simulated_refunds
        @reimbursement_objects = @reimbursement.simulate
      end

      def spree_core_gateway_error(error)
        flash[:error] = error.message
        redirect_to edit_admin_order_reimbursement_path(parent, @reimbursement)
      end
    end
  end
end

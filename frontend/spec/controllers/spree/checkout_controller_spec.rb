# frozen_string_literal: true

require 'spec_helper'

describe Spree::CheckoutController, type: :controller do
  let(:token) { 'some_token' }
  let(:user) { create(:user) }
  let(:order) { FactoryBot.create(:order_with_totals) }

  let(:address_params) do
    address = FactoryBot.build(:address)
    address.attributes.except('created_at', 'updated_at')
  end

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages current_order: order
  end

  context '#edit' do
    it 'checks if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:token] = token
      get :edit, state: 'address'
    end

    it 'redirects to the cart path unless checkout_allowed?' do
      allow(order).to receive_messages checkout_allowed?: false
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to the cart path if current_order is nil' do
      allow(controller).to receive(:current_order).and_return(nil)
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to cart if order is completed' do
      allow(order).to receive_messages(completed?: true)
      get :edit, params: { state: 'address' }
      expect(response).to redirect_to(spree.cart_path)
    end

    # Regression test for https://github.com/spree/spree/issues/2280
    it 'redirects to current step trying to access a future step' do
      order.update_column(:state, 'address')
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to spree.checkout_state_path('address')
    end

    context 'when entering the checkout' do
      before do
        # The first step for checkout controller is address
        # Transitioning into this state first is required
        order.update_column(:state, 'address')
      end

      it 'associates the order with a user' do
        order.update_column :user_id, nil
        expect(order).to receive(:associate_user!).with(user)
        get :edit, {}, order_id: 1
      end
    end
  end

  context '#update' do
    it 'checkx if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:token] = token
      post :update, params: { state: 'address' }
    end

    context 'save successful' do
      def post_address
        post :update, params: {
                   state: 'address',
                   order: {
                     bill_address_attributes: address_params,
                     use_billing: true
                   }
        }
      end

      let!(:payment_method) { create(:payment_method) }
      before do
        # Must have *a* shipping method and a payment method so updating from address works
        allow(order).to receive_messages ensure_available_shipping_rates: true
        order.line_items << FactoryBot.create(:line_item)
      end

      context 'with the order in the cart state', partial_double_verification: false do
        before do
          order.update_attributes! user: user
          order.update_column(:state, 'cart')
        end

        it 'assigns order' do
          post :update, params: { state: 'address' }
          expect(assigns[:order]).not_to be_nil
        end

        it 'advances the state' do
          post_address
          expect(order.reload.state).to eq('delivery')
        end

        it 'redirects the next state' do
          post_address
          expect(response).to redirect_to spree.checkout_state_path('delivery')
        end

        context 'current_user respond to save address method' do
          it 'calls persist order address on user' do
            expect(user).to receive(:persist_order_address)
            post :update, params: {
                       state: 'address',
                       order: {
                         bill_address_attributes: address_params,
                         use_billing: true
                       },
                       save_user_address: '1'
            }
          end
        end

        context 'current_user does not respond to persist_order_address' do
          it 'does not raise any error' do
            post :update, params: {
              state: 'address',
              order: {
                bill_address_attributes: address_params,
                use_billing: true
              },
              save_user_address: '1'
            }
          end
        end
      end

      context 'with the order in the address state', partial_double_verification: false do
        before do
          order.update_attributes! user: user
          order.update_columns(ship_address_id: create(:address).id, state: 'address')
        end

        context 'landing to address page' do
          it 'tries to associate user addresses to order' do
            expect(order).to receive(:assign_default_user_addresses)
            get :edit
          end
        end

        context 'with a billing and shipping address', partial_double_verification: false do
          subject do
            post :update, params: {
              state: 'address',
              order: {
                bill_address_attributes: order.bill_address.attributes.except('created_at', 'updated_at').compact,
                ship_address_attributes: order.ship_address.attributes.except('created_at', 'updated_at').compact,
                use_billing: false
              }
            }
          end

          it "doesn't change bill address" do
            expect {
              subject
            }.not_to change { order.reload.ship_address.id }
          end

          it "doesn't change ship address" do
            expect {
              subject
            }.not_to change { order.reload.bill_address.id }
          end
        end
      end

      # This is the only time that we need the 'set_payment_parameters_amount'
      # controller code, because otherwise the transition to 'confirm' will
      # trigger the 'add_store_credit_payments' transition code which will do
      # the same thing here.
      # Perhaps we can just remove 'set_payment_parameters_amount' entirely at
      # some point?
      context 'when there is a checkout step between payment and confirm', partial_double_verification: false do
        before do
          @old_checkout_flow = Spree::Order.checkout_flow
          Spree::Order.class_eval do
            insert_checkout_step :new_step, after: :payment
          end
        end

        after do
          Spree::Order.checkout_flow(&@old_checkout_flow)
        end

        let(:order) { create(:order_with_line_items) }
        let(:payment_method) { create(:credit_card_payment_method) }

        let(:params) do
          {
            state: 'payment',
            order: {
              payments_attributes: [
                {
                  payment_method_id: payment_method.id.to_s,
                  source_attributes: attributes_for(:credit_card)
                }
              ]
            }
          }
        end

        before do
          order.update_attributes! user: user
          3.times { order.next! } # should put us in the payment state
        end

        it 'sets the payment amount' do
          post :update, params: params
          order.reload
          expect(order.state).to eq('new_step')
          expect(order.payments.size).to eq(1)
          expect(order.payments.first.amount).to eq(order.total)
        end
      end

      context 'when in the payment state', partial_double_verification: false do
        let(:order) { create(:order_with_line_items) }
        let(:payment_method) { create(:credit_card_payment_method) }

        let(:params) do
          {
            state: 'payment',
            order: {
              payments_attributes: [
                {
                  payment_method_id: payment_method.id.to_s,
                  source_attributes: attributes_for(:credit_card)
                }
              ]
            }
          }
        end

        before do
          order.update_attributes! user: user
          3.times { order.next! } # should put us in the payment state
        end

        context 'with a permitted payment method' do
          it 'sets the payment amount' do
            post :update, params: params
            order.reload
            expect(order.state).to eq('confirm')
            expect(order.payments.size).to eq(1)
            expect(order.payments.first.amount).to eq(order.total)
          end
        end

        context 'with an unpermitted payment method' do
          before { payment_method.update!(available_to_users: false) }

          it 'sets the payment amount' do
            expect {
              post :update, params: params
            }.to raise_error(ActiveRecord::RecordNotFound)

            expect(order.state).to eq('payment')
            expect(order.payments).to be_empty
          end
        end
      end

      context 'when in the confirm state' do
        before do
          order.update_attributes! user: user
          order.update_column(:state, 'confirm')
          # An order requires a payment to reach the complete state
          # This is because payment_required? is true on the order
          create(:payment, amount: order.total, order: order)
          order.create_proposed_shipments
          order.payments.reload
        end

        # This inadvertently is a regression test for #2694
        it 'redirects to the order view' do
          post :update, params: { state: 'confirm' }
          expect(response).to redirect_to spree.order_path(order)
        end

        it 'populates the flash message' do
          post :update, params: { state: 'confirm' }
          expect(flash.notice).to eq(I18n.t('spree.order_processed_successfully'))
        end

        it 'removes completed order from current_order' do
          post :update, params: { state: 'confirm' }
          expect(assigns(:current_order)).to be_nil
          expect(assigns(:order)).to eql controller.current_order
        end
      end
    end

    context 'save unsuccessful' do
      before do
        order.update_attributes! user: user
        allow(order).to receive_messages valid?: false
      end

      it 'does not assign order' do
        post :update, params: { state: 'address' }
        expect(assigns[:order]).not_to be_nil
      end

      it 'does not change the order state' do
        post :update, params: { state: 'address' }
      end

      it 'renders the edit template' do
        post :update, params: { state: 'address' }
        expect(response).to render_template :edit
      end

      it 'renders order in payment state when payment fails' do
        order.update_column(:state, 'confirm')
        allow(controller).to receive(:insufficient_payment?).and_return(true)
        post :update, params: { state: 'confirm' }
        expect(order.state).to eq('payment')
      end
    end

    context 'when current_order is nil' do
      before { allow(controller).to receive_messages current_order: nil }

      it 'does not change the state if order is completed' do
        expect(order).not_to receive(:update_attribute)
        post :update, params: { state: 'confirm' }
      end

      it 'redirects to the cart_path' do
        post :update, params: { state: 'confirm' }
        expect(response).to redirect_to spree.cart_path
      end
    end

    context 'Spree::Core::GatewayError' do
      before do
        order.update_attributes! user: user
        allow(order).to receive(:next).and_raise(Spree::Core::GatewayError.new('Invalid something or other.'))
        post :update, params: { state: 'address' }
      end

      it 'renders the edit template and display exception message' do
        expect(response).to render_template :edit
        expect(flash.now[:error]).to eq(I18n.t('spree.spree_gateway_error_flash_for_checkout'))
        expect(assigns(:order).errors[:base]).to include('Invalid something or other.')
      end
    end

    context 'fails to transition from address' do
      let(:order) do
        FactoryBot.create(:order_with_line_items).tap do |order|
          order.next!
          expect(order.state).to eq('address')
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      context 'when the order is invalid' do
        before do
          allow(order).to receive_messages valid?: true, next: nil
          order.errors.add :base, 'Base error'
          order.errors.add :adjustments, 'error'
        end

        it 'due to the order having errors' do
          put :update, params: { state: order.state, order: {} }
          expect(flash[:error]).to eq("Base error\nAdjustments error")
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end

      context 'when the country is not a shippable country' do
        let(:foreign_address) { create(:address, country_iso: 'CA') }

        before do
          order.update(shipping_address: foreign_address)
        end

        it 'due to no available shipping rates for any of the shipments' do
          put :update, params: { state: 'address', order: {} }
          expect(flash[:error]).to eq(I18n.t('spree.items_cannot_be_shipped'))
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end
    end

    context "when GatewayError is raised" do
      let(:order) do
        FactoryBot.create(:order_with_line_items).tap do |order|
          until order.state == 'payment'
            order.next!
          end
          # So that the confirmation step is skipped and we get straight to the action.
          payment_method = FactoryBot.create(:simple_credit_card_payment_method)
          payment = FactoryBot.create(:payment, payment_method: payment_method, amount: order.total)
          order.payments << payment
          order.next!
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      it 'fails to transition from payment to complete' do
        allow_any_instance_of(Spree::Payment).to receive(:process!).and_raise(Spree::Core::GatewayError.new(I18n.t('spree.payment_processing_failed')))
        put :update, params: { state: order.state, order: {} }
        expect(flash[:error]).to eq(I18n.t('spree.payment_processing_failed'))
      end
    end

    context "when InsufficientStock error is raised" do
      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
        allow(controller).to receive_messages ensure_sufficient_stock_lines: true
      end

      context "when the order has no shipments" do
        let(:order) { Spree::TestingSupport::OrderWalkthrough.up_to(:address) }

        before do
          allow(order).to receive_messages shipments: []
          # Order#next is the tipical failure point here:
          allow(order).to receive(:next).and_raise(Spree::Order::InsufficientStock)
        end

        it "redirects the customer to the cart page with an error message" do
          put :update, params: { state: order.state, order: {} }
          expect(flash[:error]).to eq(I18n.t('spree.insufficient_stock_for_order'))
          expect(response).to redirect_to(spree.cart_path)
        end
      end

      context "when the order has shipments" do
        let(:order) { Spree::TestingSupport::OrderWalkthrough.up_to(:payment) }

        context "when items become somehow not available anymore" do
          before { Spree::StockItem.update_all backorderable: false }

          it "redirects the customer to the address checkout page with an error message" do
            put :update, params: { state: order.state, order: {} }
            error = I18n.t('spree.inventory_error_flash_for_insufficient_shipment_quantity', unavailable_items: order.products.first.name)
            expect(flash[:error]).to eq(error)
            expect(response).to redirect_to(spree.checkout_state_path(state: :address))
          end
        end
      end
    end
  end

  context 'When last inventory item has been purchased' do
    let(:product) { mock_model(Spree::Product, name: 'Amazing Object') }
    let(:variant) { mock_model(Spree::Variant) }
    let(:line_item) { mock_model Spree::LineItem, insufficient_stock?: true, amount: 0, name: 'Amazing Item' }
    let(:order) { create(:order) }

    before do
      allow(order).to receive_messages(line_items: [line_item], state: 'payment')

      configure_spree_preferences do |config|
        config.track_inventory_levels = true
      end
    end

    context 'and back orders are not allowed' do
      before do
        post :update, params: { state: 'payment' }
      end

      it 'redirects to cart' do
        expect(response).to redirect_to spree.cart_path
      end

      it 'sets flash message for no inventory' do
        expect(flash[:error]).to eq('Amazing Item became unavailable.')
      end
    end
  end

  context "order doesn't have a delivery step" do
    before do
      allow(order).to receive_messages(checkout_steps: ['cart', 'address', 'payment'])
      allow(order).to receive_messages state: 'address'
      allow(controller).to receive_messages check_authorization: true
    end

    it "doesn't set shipping address on the order" do
      expect(order).not_to receive(:ship_address=)
      post :update, params: { state: order.state }
    end

    it "doesn't remove unshippable items before payment" do
      expect {
        post :update, params: { state: 'payment' }
      }.not_to change { order.line_items }
    end
  end

  it 'does remove unshippable items before payment' do
    allow(order).to receive_messages payment_required?: true
    allow(controller).to receive_messages check_authorization: true

    expect {
      post :update, params: { state: 'payment' }
    }.to change { order.line_items.to_a.size }.from(1).to(0)
  end

  context 'in the payment step' do
    let(:order) { OrderWalkthrough.up_to(:payment) }
    let(:payment_method_id) { Spree::PaymentMethod.first.id }

    before do
      expect(order.state).to eq 'payment'
      allow(order).to receive_messages user: user
      allow(order).to receive_messages confirmation_required?: true
    end

    it 'does not advance the order extra even when called twice' do
      put :update, params: { state: 'payment',
                             order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
                           }
      order.reload
      expect(order.state).to eq 'confirm'
      put :update, params: { state: 'payment',
                             order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
                           }
      order.reload
      expect(order.state).to eq 'confirm'
    end

    context 'with store credits payment' do
      let(:user) { create(:user) }
      let(:credit_amount) { order.total + 1.00 }
      let(:put_attrs) do
        {
          state: 'payment',
          apply_store_credit: 'Apply Store Credit',
          order: {
            payments_attributes: [{ payment_method_id: payment_method_id }]
          }
        }
      end

      before do
        create(:store_credit_payment_method)
        create(:store_credit, user: user, amount: credit_amount)
      end

      def expect_one_store_credit_payment(order, amount)
        expect(order.payments.count).to eq 1
        expect(order.payments.first.source).to be_a Spree::StoreCredit
        expect(order.payments.first.amount).to eq amount
      end

      it 'can fully pay with store credits while removing other payment attributes' do
        spree_put :update, put_attrs

        order.reload
        expect(order.state).to eq 'confirm'
        expect_one_store_credit_payment(order, order.total)
      end

      it 'can fully pay with store credits while removing an existing card' do
        credit_card = create(:credit_card, user: user, payment_method: Spree::PaymentMethod.first)
        put_attrs[:order][:existing_card] = credit_card.id
        put :update, put_attrs

        order.reload
        expect(order.state).to eq 'confirm'
        expect_one_store_credit_payment(order, order.total)
      end

      context 'partial payment' do
        let(:credit_amount) { order.total - 1.00 }

        it 'returns to payment for partial store credit' do
        put :update, put_attrs

          order.reload
          expect(order.state).to eq 'payment'
          expect_one_store_credit_payment(order, credit_amount)
        end
      end
    end

    context 'remove store credits payment' do
      let(:user) { create(:user) }
      let(:credit_amount) { order.total - 1.00 }
      let(:put_attrs) do
        {
          state: 'payment',
          remove_store_credit: 'Remove Store Credit',
          order: {
            payments_attributes: [{ payment_method_id: payment_method_id }]
          }
        }
      end

      before do
        create(:store_credit_payment_method)
        create(:store_credit, user: user, amount: credit_amount)
        Spree::Checkout::AddStoreCredit.call(order: order)
      end

      def expect_invalid_store_credit_payment(order)
        expect(order.payments.store_credits.with_state(:invalid).count).to eq 1
        expect(order.payments.store_credits.with_state(:invalid).first.source).to be_a Spree::StoreCredit
      end

      it 'can fully pay with store credits while removing other payment attributes' do
        put :update, put_attrs

        order.reload
        expect(order.state).to eq 'payment'
        expect_invalid_store_credit_payment(order)
      end
    end
  end
end
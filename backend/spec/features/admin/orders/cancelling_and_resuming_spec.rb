# frozen_string_literal: true

require 'spec_helper'

describe 'Cancelling + Resuming', type: :feature do
  stub_authorization!

  let(:user) { build_stubbed(:user, id: 123, spree_api_key: 'fake') }
  let(:order) do
    order = create(:order)
    order.update_columns({ state: 'complete', completed_at: Time.current })
    order
  end

  before do
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(user)
  end
  
  it 'can cancel an order' do
    visit spree.edit_admin_order_path(order.number)
    click_button 'Cancel'
    within('.additional-info') do
      expect(find('dt#order_status + dd')).to have_content('Canceled')
    end
  end

  context 'with a cancelled order' do
    before do
      order.update_column(:state, 'canceled')
    end

    it 'can resume an order' do
      visit spree.edit_admin_order_path(order.number)
      click_button 'Resume'
      within('.additional-info') do
        expect(find('dt#order_status + dd')).to have_content('Resumed')
      end
    end
  end
end

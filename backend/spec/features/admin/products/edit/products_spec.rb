# frozen_string_literal: true

require 'spec_helper'

describe 'Product Details', type: :feature do
  stub_authorization!

  context 'editing a product', js: true do
    it 'lists the product details' do
      create(:product, name: 'Bún thịt nướng', sku: 'A100',
                       description: 'lorem ipsum', available_on: '2013-08-14 01:02:03')

      visit spree.admin_path
      click_nav 'Products'
      within_row(1) { click_icon :edit }
    
      click_link 'Product Details'

      expect(page).to have_content('Products / Bún thịt nướng')
      expect(page).to have_field('product_name', with: 'Bún thịt nướng')
      expect(page).to have_field('product_slug', with: 'bun-th-t-n-ng')
      expect(page).to have_field('product_description', with: 'lorem ipsum')
      expect(page).to have_field('product_price', with: '19.99')
      expect(page).to have_field('product_cost_price', with: '17.00')
      expect(page).to have_field('product_available_on', with: "2013/08/14")
      expect(page).to have_field('product_sku', with: 'A100')
    end

    it 'handles slug changes' do
      create(:product, name: 'Bún thịt nướng', sku: 'A100',
              description: 'lorem ipsum', available_on: '2011-01-01 01:01:01')

      visit spree.admin_path
      click_nav 'Products'
      within('table.index tbody tr:nth-child(1)') do
        click_icon(:edit)
      end

      fill_in 'product_slug', with: 'random-slug-value'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')

      fill_in 'product_slug', with: ''
      click_button 'Update'
      within('#product_slug_field') { expect(page).to have_content("can't be blank") }

      fill_in 'product_slug', with: 'x'
      click_button 'Update'
      expect(page).to have_content("successfully updated!")
    end

    it 'handles tag changes' do
      targetted_select2_search 'example-tag', from: '#s2id_product_tag_list'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(find('#s2id_product_tag_list')).to have_content('example-tag')
    end

    it 'has a link to preview a product' do
      allow(Spree::Core::Engine).to receive(:frontend_available?).and_return(true)
      allow_any_instance_of(Spree::BaseHelper).to receive(:product_url).and_return('http://example.com/products/product-slug')
      click_link 'Product Details'
      expect(page).to have_css('#admin_preview_product')
      expect(page).to have_link Spree.t(:preview_product), href: 'http://example.com/products/product-slug'
    end
  end

  # Regression test for https://github.com/spree/spree/issues/3385
  context 'deleting a product', js: true do
    it 'is still able to find the master variant' do
      create(:product)

      visit spree.admin_products_path
      within_row(1) do
        accept_alert do
          click_icon :trash
        end
      end
      expect(page).to have_content('Product has been deleted')
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe 'Product Images', type: :feature, js: true do
  stub_authorization!

  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }
  let(:product) { create(:product) }

  before do
    # Ensure attachment style keys are symbolized before running all tests
    # Otherwise this would result in this error:
    # undefined method `processors' for \"48x48>\
    Spree::Image.attachment_definitions[:attachment][:styles].symbolize_keys!
  end

  context 'uploading, editing, and deleting an image' do
    it 'allows an admin to upload and edit an image for a product' do
      create(:product)

      visit spree.admin_products_path
      click_nav 'Products'
      click_icon(:edit)
      click_link 'Images'
      click_link 'new_image_link'
      within_fieldset 'New Image' do
        attach_file('image_attachment', file_path)
      end
      click_button 'Update'
      expect(page).to have_content('successfully created!')

      # Icons are hidden, so hover to have them pop-up
      find('tbody > tr').hover
      within_row(1) do
        within '.actions' do
          click_icon :edit
        end
      end

      fill_in 'image_alt', with: 'ruby on rails t-shirt'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_content('ruby on rails t-shirt')

      find('tbody > tr').hover
      accept_alert do
        click_icon :trash
      end
      expect(page).not_to have_field 'image[alt]', with: 'ruby on rails t-shirt'
    end
  end

  # Regression test for #2228
  it 'sees variant images', js: false do
    variant = create(:variant)
    create_image(variant, File.open(file_path))
    visit spree.admin_product_images_path(variant.product)

    expect(page).not_to have_content('No Images Found.')
    within('table.table') do
      expect(page).to have_content(variant.options_text)

      # ensure no duplicate images are displayed
      expect(page).to have_css('tbody tr', count: 1)

      # ensure variant header is displayed
      within('thead') do
        expect(page.body).to have_content('Variant')
      end

      # ensure variant header is displayed
      within('tbody') do
        expect(page).to have_content('Size: S')
      end
    end
  end

  it 'does not see variant column when product has no variants' do
    product = create(:product)
    create_image(product, File.open(file_path))
    visit spree.admin_product_images_path(product)

    expect(page).not_to have_content('No Images Found.')
    within('table.index') do
      # ensure no duplicate images are displayed
      expect(page).to have_css('tbody tr', count: 1)

      # ensure variant header is not displayed
      within('thead') do
        expect(page).not_to have_content('Variant')
      end

      # ensure correct cell count
      expect(page).to have_css('thead th', count: 4)
    end
  end
end
# frozen_string_literal: true

require 'carmen'

Carmen::Country.all.each do |country|
  Spree::Country.where(
    name: country.name,
    iso3: country.alpha_3_code,
    iso: country.alpha_2_code,
    country_iso_name: country.name.upcase,
    numcode: country.numeric_code,
    states_required: country.subregions?
  ).first_or_create
end

Spree::Config[:default_country_iso] = Spree::Country.find_by(iso: 'US')

# find countries that do not use postal codes (by iso) and set 'zipcode_required' to false for them.

Spree::Country.where(iso: Spree::Address::NO_ZIPCODE_ISO_CODES).update_all(zipcode_required: false)
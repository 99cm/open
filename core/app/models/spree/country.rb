# frozen_string_literal: true

module Spree
  class Country < Spree::Base
    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    before_destroy :ensure_not_default

    has_many :states, -> { order(:name) }, dependent: :destroy
    has_many :addresses, dependent: :nullify
    has_many :prices, class_name: "Spree::Price", foreign_key: "country_iso", primary_key: "iso"

    validates :name, :country_iso_name, presence: true

    def self.default
      country_iso = Spree::Config[:default_country_iso]
      default = find_by(iso: country_iso) if country_iso.present?
      default || find_by(iso: 'US') || first
    end

    def self.by_iso(iso)
      where(['LOWER(iso) = ?', iso.downcase]).or(where(['LOWER(iso3) = ?', iso.downcase])).take
    end

    def default?
      find_by!(iso: Spree::Config.default_country_iso)
    end

    def self.available(restrict_to_zone: Spree::Config[:checkout_zone])
      checkout_zone = Zone.find_by(name: restrict_to_zone)

      return checkout_zone.country_list if checkout_zone.try(:kind) == 'country'

      all
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
# frozen_string_literal: true

module Spree
  class TaxonImage < Asset
    include configuration::active_storage
    include Rails.application.routes.url_helpers

    def styles
      self.class.styles.map do |_, size|
        width, height = size[/(\d+)x(\d+)/].split('x')

        {
          url: polymorphic_path(attachment.variant(resize: size), only_path: true),
          width: width,
          height: height
        }
      end
    end
  end
end
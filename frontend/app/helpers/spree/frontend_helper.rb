# frozen_string_literal: true

require 'core/app/helpers/spree/checkout_helper'

module Spree
  module FrontendHelper
    include CheckoutHelper

    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def spree_breadcrumbs(taxon, separator = '')
      return '' if current_page?('/') || taxon.nil?

      separator = raw(separator)
      crumbs = [content_tag(:li, content_tag(:span, link_to(content_tag(:span, I18n.t('spree.home'), itemprop: 'name'), spree.root_path, itemprop: 'url') + separator, itemprop: 'item'), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: "breadcrumb-item")]
      if taxon
        crumbs << content_tag(:li, content_tag(:span, link_to(content_tag(:span, I18n.t('spree.products'), itemprop: 'name'), spree.products_path, itemprop: 'url') + separator, itemprop: 'item'), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')
        crumbs << taxon.ancestors.collect { |ancestor| content_tag(:li, content_tag(:span, link_to(content_tag(:span, ancestor.name, itemprop: 'name'), seo_url(ancestor), itemprop: 'url') + separator, itemprop: 'item'), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item') } unless taxon.ancestors.empty?
        crumbs << content_tag(:li, content_tag(:span, link_to(content_tag(:span, taxon.name, itemprop: 'name'), seo_url(taxon), itemprop: 'url'), itemprop: 'item'), class: 'active breadcrumb-item', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
      else
        crumbs << content_tag(:li, content_tag(:span, I18n.t('spree.products'), itemprop: 'item'), class: 'active', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
      end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map(&:mb_chars).join), class: 'breadcrumb', itemscope: 'itemscope', itemtype: 'https://schema.org/BreadcrumbList')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-12 mt-4', aria: { label: 'breadcrumb' })
    end

    def flash_messages(opts = {})
      ignore_types = ['order_completed'].concat(Array(opts[:ignore_types]).map(&:to_s) || [])

      flash.each do |msg_type, text|
        concat(content_tag(:div, text, class: "alert alert-#{msg_type}")) unless ignore_types.include?(msg_type)
      end
      nil
    end

    def link_to_cart(text = nil)
      text = text ? h(text) : I18n.t('spree.cart')
      css_class = nil

      if simple_current_order.nil? || simple_current_order.item_count.zero?
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{I18n.t('spree.empty')})"
        css_class = 'empty'
      else
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{simple_current_order.item_count})
                <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end

      link_to text.html_safe, spree.cart_path, class: "cart-info nav-link #{css_class}"
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      return '' if max_level < 1 || root_taxon.leaf?

      content_tag :div, class: 'list-group' do
        taxons = root_taxon.children.map do |taxon|
          css_class = current_taxon&.self_and_ancestors&.include?(taxon) ? 'list-group-item list-group-item-action active' : 'list-group-item list-group-item-action'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end
        safe_join(taxons, "\n")
      end
    end

    def set_image_alt(image, size)
      image.alt.present? ? image.alt : image_alt(main_app.url_for(image.url(size)))
    end
  end
end
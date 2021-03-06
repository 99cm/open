# frozen_string_literal: true

require 'rails_helper'
require 'shared_examples/calculator_shared_examples'

module Spree
  module Calculator::Shipping
    RSpec.describe FlatPercentItemTotal, type: :model do
      subject { FlatPercentItemTotal.new(preferred_flat_percent: 10) }

      it_behaves_like 'a calculator with a description'

      let(:line_item1) { build(:line_item, price: 10.11) }
      let(:line_item2) { build(:line_item, price: 20.2222) }

      let(:inventory_unit1) { build(:inventory_unit, line_item: line_item1) }
      let(:inventory_unit2) { build(:inventory_unit, line_item: line_item2) }

      let(:package) do
        build(
          :stock_package,
          contents: [
            Spree::Stock::ContentItem.new(inventory_unit1),
            Spree::Stock::ContentItem.new(inventory_unit1),
            Spree::Stock::ContentItem.new(inventory_unit2),
          ]
        )
      end

      it 'rounds result correctly' do
        expect(subject.compute(package)).to eq(4.04)
      end

      it 'rounds result based on order currency' do
        package.order.currency = 'JPY'
        expect(subject.compute(package)).to eq(4)
      end

      it 'returns a bigdecimal' do
        expect(subject.compute(package)).to be_a(BigDecimal)
      end
    end
  end
end

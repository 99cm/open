# frozen_string_literal: true

require 'rails_helper'

module Spree
  module Stock
    RSpec.describe InventoryUnitBuilder, type: :model do
      let(:line_item_1) { create(:line_item) }
      let(:line_item_2) { create(:line_item, quantity: 2) }
      let(:order) { build(:order, line_items: [line_item_1, line_item_2]) }

      subject { InventoryUnitBuilder.new(order) }

      describe '#units' do
        it "returns an inventory unit for each quantity for the order's line items" do
          units = subject.units
          expect(units.count).to eq 3
          expect(units.first.line_item).to eq line_item_1
          expect(units.first.variant).to eq line_item_1.variant

          expect(units[1].line_item).to eq line_item_2
          expect(units[1].variant).to eq line_item_2.variant

          expect(units[2].line_item).to eq line_item_2
          expect(units[2].variant).to eq line_item_2.variant
        end

        it 'builds the inventory units as pending' do
          expect(subject.units.map(&:pending).uniq).to eq [true]
        end
      end
    end
  end
end
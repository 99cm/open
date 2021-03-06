# frozen_string_literal: true

module Spree
  # Spree::OrderMerger is responsible for taking two orders and merging them
  # together by adding the line items from additional orders to the order
  # that the OrderMerger is initialized with.
  #
  # Orders that are merged should be incomplete orders which should belong to
  # the same user. They should also be in the same currency.
  class OrderMerger
    # @!attribute order
    #   @api public
    #   @return [Spree::Order] The order which items wll be merged into.
    attr_accessor :order
    delegate :updater, to: :order

    # Create the OrderMerger
    #
    # @api public
    # @param [Spree::Order] order The order which line items will be merged into.
    def initialize(order)
      @order = order
    end

    # Merge a second order in to the order the OrderMerger was initialized with
    #
    # The line items from `other_order` will be merged in to the `order` for
    # this OrderMerger object. If the line items are for the same variant, it
    # will add the quantity of the incoming line item to the existing line item.
    # Otherwise, it will assign the line item to the new order.
    #
    # After the orders have been merged the `other_order` will be destroyed.
    #
    # @example
    #   initial_order = Spree::Order.find(1)
    #   order_to_merge = Spree::Order.find(2)
    #   merger = Spree::OrderMerger.new(initial_order)
    #   merger.merge!(order_to_merge)
    #   # order_to_merge is destroyed, initial order now contains the line items
    #   # of order_to_merge
    #
    # @api public
    # @param [Spree::Order] other_order An order which will be merged in to the
    # order the OrderMerger was initialized with.
    # @param [Spree::User] user Associate the order the user specified. If not
    # specified, the order user association will not be changed.
    # @return [void]
    def merge!(other_order, user = nil)
      if other_order.currency == order.currency
        other_order.line_items.each do |other_order_line_item|
          current_line_item = find_matching_line_item(other_order_line_item)
          handle_merge(current_line_item, other_order_line_item)
        end
      end

      set_user(user)
      persist_merge

      # So that the destroy doesn't take out line items which may have been re-assigned
      other_order.line_items.reload
      other_order.destroy
    end

    private

    # Retreive a matching line item from the existing order
    #
    # It will compare line items based on variants, and all line item
    # comparison hooks on the order.
    #
    # @api private
    # @param [Spree::LineItem] other_order_line_item The line item from
    # `other_order` we are attempting to merge in.
    # @return [Spree::LineItem] A matching line item from the order. nil if none exist.
    def find_matching_line_item(other_order_line_item)
      order.line_items.detect do |my_li|
        my_li.variant == other_order_line_item.variant &&
          Spree::Dependencies.cart_compare_line_items_service.constantize.new.call(order: order,
                                                                                   line_item: my_li,
                                                                                   options: other_order_line_item.serializable_hash).value
      end
    end

    def set_user(user)
      order.associate_user!(user) if !order.user && user
    end

    # The idea is the end developer can choose to override the merge
    # to their own choosing. Default is merge with errors.
    def handle_merge(current_line_item, other_order_line_item)
      if current_line_item
        current_line_item.quantity += other_order_line_item.quantity
        handle_error(current_line_item) unless current_line_item.save
      else
        order.line_items << other_order_line_item
        handle_error(other_order_line_item) unless other_order_line_item.save
      end
    end

    # Change the error messages as you choose.
    def handle_error(line_item)
      order.errors[:base] << line_item.errors.full_messages
    end

    def persist_merge
      updater.update
    end
  end
end
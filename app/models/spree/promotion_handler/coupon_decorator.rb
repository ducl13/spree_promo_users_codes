Spree::PromotionHandler::Coupon.class_eval do
  def determine_promotion_application_result
    # Check for applied adjustments.
    discount = order.all_adjustments.promotion.eligible.detect do |p|
      source_promotion = p.source.promotion
      if source_promotion.multi_coupon? && order.user && source_promotion.codes.present?
        source_promotion.codes.where(user: order.user).where("LOWER(code) = ?", order.coupon_code.downcase).present?
      else
        source_promotion.code.try(:downcase) == order.coupon_code.downcase
      end
    end

    # Check for applied line items.
    created_line_items = promotion.actions.detect { |a| a.type == 'Spree::Promotion::Actions::CreateLineItems' }

    if discount || created_line_items
      order.update_totals
      order.persist_totals
      update_used_for_promotion_code
      set_success_code :coupon_code_applied
    else
      # if the promotion exists on an order, but wasn't found above,
      # we've already selected a better promotion
      if order.promotions.with_coupon_code(order.coupon_code)
        set_error_code :coupon_code_better_exists
      else
        # if the promotion was created after the order
        set_error_code :coupon_code_not_found
      end
    end
  end

  def update_used_for_promotion_code
    promotion = order.promotions.with_coupon_code(order.coupon_code)
    if promotion.multi_coupon?
      promotion_code = promotion.codes.where("LOWER(code) = ?", order.coupon_code.downcase).first
      promotion_code.update_column(:used, true)
    end
  end
end

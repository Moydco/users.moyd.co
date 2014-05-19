module ChecksHelper
  # For topup, link the show invoice or upload invoice
  def link_to_document(activity)
    if activity.kind == 'topup'
      if current_user.is_admin?
        edit_user_topup_path(activity.user,activity.id)
      else
        user_topup_path(current_user,activity.id)
      end
    elsif activity.kind == 'voucher'
      '#'
    elsif activity.kind == 'consume'
      '#'
    end
  end

  # Tooltip text for user activity list
  def tooltip_text(activity)
    if activity.kind == 'topup'
      if current_user.is_admin?
        'Click me to upload invoice'
      else
        'Click me to download invoice'
      end
    elsif activity.kind == 'voucher'
      "This voucher was emitted on #{activity.voucher.created_at}. The amount of #{(activity.amount.to_f/100).to_s} UKP has been credited on #{activity.created_at}" unless activity.voucher.nil?
    elsif activity.kind == 'consume'
      "The consumption is referred to #{activity.consume.description}"  unless activity.consume.nil?
    end
  end
end
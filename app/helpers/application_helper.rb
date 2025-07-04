module ApplicationHelper
  def number_with_sign(number, **options)
    sign = number.positive? ? '+' : number.negative? ? '-' : ''
    formatted = number_with_precision(number.abs, **options)
    "#{sign}#{formatted}"
  end
end

module DateHelper
  def pretty_date(date)
    return 'Invalid date' unless date.is_a?(Date) || date.is_a?(Time)

    date.strftime('%B %e, %Y')
  end

  def pretty_datetime(datetime)
    return 'Invalid date/time' unless datetime.is_a?(DateTime) || datetime.is_a?(Time)

    datetime.strftime('%B %e, %Y, %l:%M%P')
  end
end

module DateHelper
  def local_date_short(date)
    local_date(date, "%b %e#{', %Y' unless date.year == Time.current.year}")
  end
end

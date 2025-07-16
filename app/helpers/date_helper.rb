module DateHelper
  def local_date_short(date)
    local_date(date, "%B %e#{', %Y' unless date.year == Time.current.year}")
  end
end

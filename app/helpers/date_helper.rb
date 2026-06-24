module DateHelper
  def local_date_short(date)
    local_date(date, "%B %e#{', %Y' unless date.year == Time.current.year}")
  end

  def local_time_short(date)
    local_time(date, "%b %e, #{'%Y' unless date.year == Time.current.year} %l:%M%P")
  end
end

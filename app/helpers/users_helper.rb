module UsersHelper
  def user_initials(user)
    source = user.name.presence || user.email_address
    words = source.split(/[\s@._-]+/).reject(&:blank?)
    words = words.first(1) unless user.name?

    words.values_at(0, -1).uniq.compact.map { it[0] }.join.upcase.first(2)
  end
end

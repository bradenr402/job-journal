if Rails.env.development? && defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  # Bullet.add_footer = true

  Bullet.counter_cache_enable = false
  Bullet.add_safelist type: :unused_eager_loading, class_name: 'JobLead', association: :interviews
  Bullet.add_safelist type: :unused_eager_loading, class_name: 'JobLead', association: :notes
  Bullet.add_safelist type: :unused_eager_loading, class_name: 'JobLead', association: :tags
  Bullet.add_safelist type: :unused_eager_loading, class_name: 'JobLead', association: :taggings
  Bullet.add_safelist type: :unused_eager_loading, class_name: 'Interview', association: :notes
end

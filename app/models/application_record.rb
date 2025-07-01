class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def edited?
    respond_to?(:created_at) && respond_to?(:updated_at) && updated_at.present? && created_at.present? && updated_at > created_at
  end
end

class Page < ApplicationRecord
  # Singleton: the homepage has exactly one row of markdown content.
  def self.current
    first_or_create!
  end
end

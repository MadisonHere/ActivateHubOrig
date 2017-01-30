class Site < ApplicationRecord

  has_many :site_domains, dependent: :destroy
  has_many :topics
  has_many :types

  after_create :create_domain!

  validates :name, :presence => true
  validates :domain, :presence => true, :uniqueness => true
  validates :timezone, :presence => true
  validates :locale, :presence => true

  def self.with_site(domain, &block)
    find_by_domain!(domain).with_site(&block)
  end


  def venues_google_map_options
    {
      :center => [ map_latitude, map_longitude ],
      :zoom => map_zoom,
    }
  end

  def with_site(&block)
    orig = ApplicationRecord.current_site

    begin
      use!
      yield(self)
    ensure
      orig ? orig.use! : nil
    end
  end

  def use!(&block)
    ApplicationRecord.current_site = self
    I18n.locale = locale
    Time.zone = timezone
    self
  end

  private def create_domain!
    site_domains.create!(domain: domain, redirect: false)
  end

end

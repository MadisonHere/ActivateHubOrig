# == Schema Information
# Schema version: 20110604174521
#
# Table name: venues
#
#  id              :integer         not null, primary key
#  title           :string(255)
#  description     :text
#  address         :string(255)
#  url             :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  street_address  :string(255)
#  locality        :string(255)
#  region          :string(255)
#  postal_code     :string(255)
#  country         :string(255)
#  latitude        :decimal(, )
#  longitude       :decimal(, )
#  email           :string(255)
#  telephone       :string(255)
#  source_id       :integer
#  duplicate_of_id :integer
#  version         :integer
#  closed          :boolean
#  wifi            :boolean
#  access_notes    :text
#  events_count    :integer
#

class Venue < ApplicationRecord
  include SearchEngine
  include StripWhitespace
  include UrlValidator

  has_paper_trail :class_name => '::Version', :meta => { :site_id => :site_id }
  acts_as_taggable

  include VersionDiff

  xss_foliate :sanitize => [:description, :access_notes]
  include DecodeHtmlEntitiesHack

  # Associations
  has_many :events
  belongs_to :source
  belongs_to :site
  scope_to_current_site

  # Triggers
  strip_whitespace! :title, :description, :address, :url, :street_address, :locality, :region, :postal_code, :country, :email, :telephone
  before_save :geocode
  after_save :touch_events

  # Validations
  validates_presence_of :title

  before_validation :normalize_url!
  validates_format_of :url,
    :with => WEBSITE_FORMAT,
    :allow_blank => true,
    :allow_nil => true

  validates_inclusion_of :latitude, :longitude,
    :in => -180..180,
    :allow_nil => true,
    :message => "must be between -180 and 180"

  validates :address, :length => { :maximum => 255 }
  validates :country, :length => { :maximum => 255 }
  validates :email, :length => { :maximum => 255 }
  validates :locality, :length => { :maximum => 255 }
  validates :postal_code, :length => { :maximum => 255 }
  validates :region, :length => { :maximum => 255 }
  validates :street_address, :length => { :maximum => 255 }
  validates :telephone, :length => { :maximum => 255 }
  validates :title, :length => { :maximum => 255 }
  validates :url, :length => { :maximum => 255 }

  include ValidatesBlacklistOnMixin
  validates_blacklist_on :title, :description, :address, :url, :street_address, :locality, :region, :postal_code, :country, :email, :telephone

  include UpdateUpdatedAtMixin

  # Duplicates
  include DuplicateChecking
  duplicate_checking_ignores_attributes    :source_id, :version, :closed, :wifi, :access_notes, :events_count, :description, :address, :url, :street_address, :locality, :region, :postal_code, :country, :latitude, :longitude, :email, :telephone
  duplicate_squashing_ignores_associations :tags, :base_tags, :taggings

  # Named scopes
  scope :masters, -> {
    where(duplicate_of_id: nil).includes(:source, :events, :tags, :taggings)
  }
  scope :with_public_wifi, -> { where(wifi: true) }
  scope :in_business, -> { where(closed: false) }
  scope :out_of_business, -> { where(closed: true) }

  #===[ Instantiators ]===================================================

  # Returns a new Venue for the +abstract_location+ retrieved from +source+.
  def self.from_abstract_location(abstract_location, source=nil)
    venue = Venue.new

    # TODO Figure out if +abstract_location+ can ever be blank. If it can be blank, rework the later code in this method so that #geocode and duplicate finders aren't called on an effectively blank record. If it can't be blank, remove this unnecessary "unless" conditional.
    unless abstract_location.blank?
      venue.source = source if source

      fields = [
        :url, :title, :description, :address, :street_address, :locality,
        :region, :postal_code, :country, :latitude, :longitude, :email,
        :telephone,
      ]

      fields.each do |field|
        value = abstract_location.send(field).presence or next
        venue.send("#{field}=", value)
      end

      venue.tag_list = abstract_location.tags.join(',')
    end

    # We must add geocoding information so this venue can be compared to existing ones.
    venue.geocode

    # if the new venue has no exact duplicate, use the new venue
    # otherwise, find the ultimate master and return it
    duplicates = venue.find_exact_duplicates

    if duplicates.present?
      venue = duplicates.first.progenitor
    else
      venue_machine_tag_name = abstract_location.tags.find { |t|
        # Match 2 in the MACHINE_TAG_PATTERN is the predicate
        ActsAsTaggableOn::Tag::VENUE_PREDICATES.include? t.match(ActsAsTaggableOn::Tag::MACHINE_TAG_PATTERN)[2]
      }
      matched_venue = Venue.tagged_with(venue_machine_tag_name).first

      venue = matched_venue.progenitor if matched_venue.present?
    end

    return venue
  end

  #===[ Finders ]=========================================================

  # Return Hash of Venues grouped by the +type+, e.g., a 'title'. Each Venue
  # record will include an <tt>events_count</tt> field containing the number of
  # events at the venue, which improves performance for displaying these.
  def self.find_duplicates_by_type(type='na')
    case type
    when 'na', nil, ''
      # The LEFT OUTER JOIN makes sure that venues without any events are also returned.
      return { [] => \
        self.where('venues.duplicate_of_id IS NULL').order('LOWER(venues.title)')
      }
    else
      kind = %w[all any].include?(type) ? type.to_sym : type.split(',')

      return self.find_duplicates_by(kind, 
        :grouped  => true, 
        :where    => 'a.duplicate_of_id IS NULL AND b.duplicate_of_id IS NULL'
      )
    end
  end

  #===[ Address helpers ]=================================================

  # Does this venue have any address information?
  def has_full_address?
    return [street_address, locality, region, postal_code, country].any?(&:present?)
  end

  def full_address_changed?
    [ street_address_changed?, locality_changed?, region_changed?,
      postal_code_changed?, country_changed?
    ].any?
  end

  # Display a single line address.
  def full_address
    if has_full_address?
      "#{street_address}, #{locality} #{region} #{postal_code} #{country}"
    else
      nil
    end
  end

  #===[ Geocoding helpers ]===============================================

  @@_is_geocoding = true

  # Should geocoding be performed?
  def self.perform_geocoding?
    return @@_is_geocoding
  end

  # Set whether to perform geocoding to the boolean +value+.
  def self.perform_geocoding=(value)
    return @@_is_geocoding = value
  end

  # Run the block with geocoding enabled, then reset the geocoding back to the
  # previous state. This is typically used in tests.
  def self.with_geocoding(&block)
    original = self.perform_geocoding?
    begin
      self.perform_geocoding = true
      block.call
    ensure
      self.perform_geocoding = original
    end
  end

  def geocode_address_changed?
    full_address ? full_address_changed? : address_changed?
  end

  # Get an address we can use for geocoding
  def geocode_address
    full_address or address
  end

  def location_changed?
    latitude_changed? || longitude_changed?
  end

  # Return this venue's latitude/longitude location,
  # or nil if it doesn't have one.
  def location
    [latitude, longitude] unless latitude.blank? or longitude.blank?
  end

  # Should we default to forcing geocoding when the user edits this venue?
  def force_geocoding
    location.nil? # Yes, if it has no location.
  end

  # Maybe trigger geocoding when we save
  def force_geocoding=(force_it)
    self.latitude = self.longitude = nil if force_it
  end

  # Try to geocode, but don't complain if we can't.
  # TODO Consider renaming this to #add_geocoding! to imply that this method makes destructive changes the object, rather than just returning values. Compare its name to the method called #geocode_address, which just returns values.
  def geocode
    return unless self.class.perform_geocoding? # is software configured
    return if duplicate_of.present? # skip if duplicate, won't be visible
    return if geocode_address.blank? # skip if no address to geocode
    return if location.present? && location_changed? # skip if manually entered

    # avoid [re]geocoding when nothing has changed
    return unless location.blank? || geocode_address_changed?

    geo = Geokit::Geocoders::MultiGeocoder.geocode(geocode_address)
    if geo.success
      self.latitude       = geo.lat
      self.longitude      = geo.lng
      self.street_address = geo.street_address if self.street_address.blank?
      self.locality       = geo.city           if self.locality.blank?
      self.region         = geo.state          if self.region.blank?
      self.postal_code    = geo.zip            if self.postal_code.blank?
      self.country        = geo.country_code   if self.country.blank?
      self.geo_precision  = geo.precision      if self.geo_precision.blank?
    end

    msg = 'Venue#add_geocoding for ' + (self.new_record? ? 'new record' : "record #{self.id}") + ' ' + (geo.success ? 'was successful' : 'failed') + ', response was: ' + geo.inspect
    Rails.logger.info(msg)

    return true
  end

  private

  def touch_events
    events.update_all(:updated_at => Time.zone.now)
  end

end

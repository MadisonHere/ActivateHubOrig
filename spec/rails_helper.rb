# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
require_relative 'spec_helper_extensions.rb'

# Checks for pending migration and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Allows us to use create(:user) instead of FactoryGirl.create :user
  config.include FactoryGirl::Syntax::Methods

  config.include Shoulda::Matchers::ActiveModel, type: :model
  config.include Shoulda::Matchers::ActiveRecord, type: :model

  # Makes warden available in tests, provides :sign_in and :sign_out
  config.include Devise::Test::ControllerHelpers, :type => :controller
  config.include Devise::Test::IntegrationHelpers, :type => :request

  # Some of the controller specs are using capybara-based matchers
  config.include Capybara::RSpecMatchers, :type => :controller

  # custom helpers and mixins, see spec/support/*
  config.include ControllerHelper, :type => :controller

  # Include contexts or shared examples when following metadata is used
  config.include_context "site"
  config.include_context "requires user login", :requires_user
  config.include_context "requires admin login", :requires_admin

  # Prevent timecop from being used in a way that can bleed between specs
  Timecop.safe_mode = true

  config.around(:all, :timecop_freeze => lambda {|v| !!v }) do |ex|
    metadata_value = ex.example.metadata[:timecop_freeze]
    freeze_at = metadata_value === true ? Time.zone.now : metadata_value
    Timecop.freeze(freeze_at.change(:nsec => 0)) { ex.run }
  end

  config.before(:suite) do
    # data is tenantized by site, so we need to ensure a site exists for
    # all tests and that it matches the request.domain used for controller
    # and functional tests.
    ENV['TEST_REQ_HOST'] ||= 'activate.test'
    Site.destroy_all
    Site.create!(
      :name     => 'Test Site',
      :domain   => ENV['TEST_REQ_HOST'],
      :timezone => 'Pacific Time (US & Canada)',
      :locale   => 'en',
    ).use!
  end

end

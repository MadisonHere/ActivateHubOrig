require 'rubygems'
require 'spork'
#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  # This file is copied to spec/ when you run 'rails generate rspec:install'

  # Calagator:
  ENV['RAILS_ENV'] = 'test' if ENV['RAILS_ENV'].to_s.empty? || ENV['RAILS_ENV'] == 'development'

  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  # Calagator: Load this project's custom spec extensions:
  require File.expand_path(File.dirname(__FILE__) + '/spec_helper_extensions.rb')

  RSpec.configure do |config|
    # == Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

    # Filter out gems from backtraces
    config.backtrace_exclusion_patterns << /vendor\//
    config.backtrace_exclusion_patterns << /lib\/rspec\/rails/
    config.backtrace_exclusion_patterns << /gems\//

    config.use_transactional_fixtures = true

    # Allows us to use create(:user) instead of FactoryGirl.create :user
    config.include FactoryGirl::Syntax::Methods

    config.include Shoulda::Matchers::ActiveModel, type: :model
    config.include Shoulda::Matchers::ActiveRecord, type: :model

    # Makes warden available in tests, provides :sign_in and :sign_out
    config.include Devise::Test::ControllerHelpers, :type => :controller

    # Some of the controller specs are using capybara-based matchers
    config.include Capybara::RSpecMatchers, :type => :controller

    # custom helpers and mixins, see spec/support/*
    config.include ControllerHelper, :type => :controller

    # Database cleaner
    config.before(:suite) do
      # use a fixed time so tests and fixtures can make assumptions
      # about future events and not worry about changes in seconds, etc
      Timecop.travel(Time.zone.parse('2013-03-22 14:05:27'))
      Timecop.safe_mode = true
    end

    config.before(:each) do
      # data is tenantized by site, so we need to ensure a site exists for
      # all tests and that it matches the request.domain used for controller
      # and functional tests.
      ENV['TEST_REQ_HOST'] = 'activate.test'
      Site.create(
        :name     => 'Test Site',
        :domain   => ENV['TEST_REQ_HOST'],
        :timezone => 'Pacific Time (US & Canada)',
        :locale   => 'en',
      ).use!
    end
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.

end

# --- Instructions ---
# Sort the contents of this file into a Spork.prefork and a Spork.each_run
# block.
#
# The Spork.prefork block is run only once when the spork server is started.
# You typically want to place most of your (slow) initializer code in here, in
# particular, require'ing any 3rd-party gems that you don't normally modify
# during development.
#
# The Spork.each_run block is run each time you run your specs.  In case you
# need to load files that tend to change during development, require them here.
# With Rails, your application modules are loaded automatically, so sometimes
# this block can remain empty.
#
# Note: You can modify files loaded *from* the Spork.each_run block without
# restarting the spork server.  However, this file itself will not be reloaded,
# so if you change any of the code inside the each_run block, you still need to
# restart the server.  In general, if you have non-trivial code in this file,
# it's advisable to move it into a separate file so you can easily edit it
# without restarting spork.  (For example, with RSpec, you could move
# non-trivial code into a file spec/support/my_helper.rb, making sure that the
# spec/support/* files are require'd from inside the each_run block.)
#
# Any code that is left outside the two blocks will be run during preforking
# *and* during each_run -- that's probably not what you want.
#
# These instructions should self-destruct in 10 seconds.  If they don't, feel
# free to delete them.

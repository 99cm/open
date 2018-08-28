# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start('rails')
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

require 'spree_frontend'
require 'spree/testing_support/dummy_app'
DummyApp.setup(
  gem_root: File.expand_path('..', __dir__),
  lib_name: 'spree_frontend'
)

require 'rails-controller-testing'
require 'rspec/rails'
require 'rspec-activemodel-mocks'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'database_cleaner'

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/caching'

require 'capybara-screenshot/rspec'

Capybara.save_path = ENV['CIRCLE_ARTIFACTS'] if ENV['CIRCLE_ARTIFACTS']
Capybara.default_max_wait_time = ENV['DEFAULT_MAX_WAIT_TIME'].to_f if ENV['DEFAULT_MAX_WAIT_TIME'].present?

require "selenium/webdriver"
Capybara.javascript_driver = (ENV['CAPYBARA_DRIVER'] || :selenium_chrome_headless).to_sym

ActiveJob::Base.queue_adapter = :test

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.fixture_path = File.join(__dir__, "fixtures")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Config for running specs while have transition period from Paperclip to ActiveStorage
  if Rails.application.config.use_paperclip
    config.filter_run_excluding :active_storage
  else
    config.filter_run_including :active_storage
    config.run_all_when_everything_filtered = true
  end

  if ENV['WEBDRIVER'] == 'accessible'
    config.around(:each, inaccessible: true) do |example|
      Capybara::Accessible.skip_audit { example.run }
    end
  end

  # Ensure DB is clean, so that transaction isolated specs see
  # pristine state.
  config.before(:suite) do
   DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do
     Rails.cache.clear
    reset_spree_preferences
  end

  config.before(:each, type: :feature) do
    if page.driver.browser.respond_to?(:url_blacklist)
      page.driver.browser.url_blacklist = ['http://fonts.googleapis.com']
    end
  end

  config.after(:each, type: :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end

  config.include FactoryBot::Syntax::Methods

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::Flash

  config.example_status_persistence_file_path = "./spec/examples.txt"

  config.order = :random
  Kernel.srand config.seed
end

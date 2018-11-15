# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group 'Libraries', 'lib/spree'

    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/script/'
    add_filter '/spec/'
    add_filter '/lib/generators/'

    coverage_dir "#{ENV['COVERAGE_DIR']}/backend" if ENV['COVERAGE_DIR']
  end
end

# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV['RAILS_ENV'] ||= 'test'

require 'open_backend'
'spree/testing_support/dummy_app'
DummyApp.setup(
  gem_root: File.expand_path('..', __dir__),
  lib_name: 'open_backend'
)

require 'rails-controller-testing'
require 'rspec-activemodel-mocks'
require 'rspec/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'database_cleaner'
require 'with_model'

require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/factories'
require 'spree/testing_support/preferences'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/flash'
require 'spree/testing_support/url_helpers'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/capybara_config'
require 'spree/testing_support/image_helpers'

ActionView::Base.raise_on_missing_translations = true

ActiveJob::Base.queue_adapter = :test

RSpec.configure do |config|
  config.color = true
  config.default_formatter = 'doc'
  config.infer_spec_type_from_file_location!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, comment the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.before :suite do
    DatabaseCleaner.clean_with :truncation
  end

  config.when_first_matching_example_defined(type: :feature) do
    config.before :suite do
      # Preload assets
      # This should avoid capybara timeouts, and avoid counting asset compilation
      # towards the timing of the first feature spec.
      Rails.application.precompiled_assets
    end
  end

  config.before do
    Rails.cache.clear
    reset_spree_preferences
    if RSpec.current_example.metadata[:js] && page.driver.browser.respond_to?(:url_blacklist)
      page.driver.browser.url_blacklist = ['http://fonts.googleapis.com']
    end
  end

  config.include BaseFeatureHelper, type: :feature

  config.after(:each, type: :feature) do |example|
    missing_translations = page.body.scan(/translation missing: #{I18n.locale}\.(.*?)[\s<\"&]/)
    if missing_translations.any?
      puts "Found missing translations: #{missing_translations.inspect}"
      puts "In spec: #{example.location}"
    end
  end

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  config.include Spree::TestingSupport::Preferences
  config.include Spree::TestingSupport::UrlHelpers
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::Flash
  config.include Spree::TestingSupport::ImageHelpers

  config.extend WithModel

  config.example_status_persistence_file_path = "./spec/examples.txt"

  config.order = :random
  Kernel.srand config.seed
end

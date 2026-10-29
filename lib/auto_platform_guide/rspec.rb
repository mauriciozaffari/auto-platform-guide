# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'capybara'

module AutoPlatformGuide
  # RSpec wiring for system specs: a rack_test default, a real browser where a
  # spec needs one (examples tagged :js, plus every system spec when
  # SCREENSHOTS=true), doc_screenshot support, and forgery protection.
  #
  #   RSpec.configure do |config|
  #     AutoPlatformGuide.setup_rspec(config)
  #   end
  #
  # The browser driver is configuration.browser_driver (:playwright default,
  # :selenium supported).
  module DocScreenshotHelper
    # Conditional screenshot capture. Enable with: SCREENSHOTS=true rspec spec/...
    def doc_screenshot(filename)
      return unless AutoPlatformGuide.screenshots_enabled?

      sleep 0.5 # Allow time for animations to complete
      directory = AutoPlatformGuide.configuration.screenshots_dir
      directory = File.join(directory, ENV['DOC_LOCALE']) if ENV['DOC_LOCALE'].present?
      save_screenshot(Rails.root.join(directory, "#{filename}.png")) # rubocop:disable Lint/Debugger
    end
  end

  def self.setup_rspec(config)
    # A contended machine (CI, or sibling spec:parallel workers) lets async Turbo
    # Stream deliveries exceed a short wait. Only the slow path lengthens.
    contended = ci? || ENV.key?('TEST_ENV_NUMBER')
    max_wait_time = contended ? 10 : 5

    screen_size = ENV.fetch('CAPYBARA_WINDOW_SIZE', '1920,900').split(',').map(&:to_i)
    browser_options = driver_options(max_wait_time)

    configure_capybara

    Capybara.save_path = './log/capybara'

    config.include DocScreenshotHelper, type: :system

    # rack_test by default, for performance
    config.before(type: :system) do
      AutoPlatformGuide.prepare_system_example(self, max_wait_time, screen_size, browser_options)
    end

    config.around(:each, type: :system) do |example|
      AutoPlatformGuide.with_forgery_protection(example)
    end

    config.before(type: :system, js: true) do
      AutoPlatformGuide.prepare_js_example(self, screen_size, browser_options)
    end
  end

  def self.apply_doc_locale
    locale = ENV.fetch('DOC_LOCALE', nil)
    I18n.locale = locale if locale.present?
  end

  def self.prepare_system_example(example, max_wait_time, screen_size, browser_options)
    Capybara.default_max_wait_time = max_wait_time
    apply_doc_locale

    if screenshots_enabled?
      drive_with_browser(example, screen_size:, options: browser_options)
    else
      example.driven_by(:rack_test)
    end
  end

  def self.with_forgery_protection(example)
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  def self.prepare_js_example(example, screen_size, browser_options)
    drive_with_browser(example, screen_size:, options: browser_options)
    attach_browser_logging(example) if configuration.browser_driver == :playwright
  end

  def self.configure_capybara
    Capybara.configure do |capybara|
      capybara.server_host = ENV.fetch(
        'CAPYBARA_SERVER_HOST',
        ci? ? IPSocket.getaddress(Socket.gethostname) : 'localhost'
      )

      # Different ports per parallel worker to avoid conflicts
      base_port = ci? ? 3000 : 3500
      port_offset = ENV['TEST_ENV_NUMBER'].to_i
      capybara.server_port = base_port + port_offset

      capybara.app_host = ENV.fetch('CAPYBARA_APP_HOST', "http://#{capybara.server_host}:#{capybara.server_port}")
      capybara.raise_server_errors = false
    end
  end

  def self.drive_with_browser(example, screen_size:, options:)
    case configuration.browser_driver
    when :playwright
      example.driven_by(:playwright, screen_size:, options:)
    when :selenium
      example.driven_by(:selenium, using: :headless_chrome, screen_size:)
    else
      raise ArgumentError, "Unknown browser_driver: #{configuration.browser_driver.inspect}"
    end
  end

  # Each example gets a fresh browser context, so web storage cannot leak between them.
  def self.attach_browser_logging(example)
    example.page.driver.with_playwright_page do |playwright_page|
      playwright_page.on('console', lambda { |message|
        Rails.logger.error("[BROWSER][#{message.type}] #{message.text}") if message.type == 'error'
      })
      playwright_page.on('pageerror', lambda { |error|
        Rails.logger.error("[BROWSER][pageerror] #{error.message}")
      })
    end
  end

  def self.driver_options(max_wait_time)
    return {} unless configuration.browser_driver == :playwright

    # Keystrokes would otherwise inherit Playwright's own 30s timeout; navigation keeps a
    # long budget because a click that waits for one is bounded by the action timeout.
    { default_timeout: max_wait_time, default_navigation_timeout: 30 }
  end

  def self.ci?
    ENV['CI'].present?
  end

  def self.screenshots_enabled?
    ENV['SCREENSHOTS'] == 'true'
  end
end

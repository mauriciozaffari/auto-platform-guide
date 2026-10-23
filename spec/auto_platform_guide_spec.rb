# frozen_string_literal: true

require 'logger'
require 'rake'
require 'spec_helper'
require 'auto_platform_guide/rspec'

RSpec.describe AutoPlatformGuide do
  let(:rails_stub) do
    Module.new do
      class << self
        attr_accessor :root, :logger
      end
    end
  end

  before do
    stub_const('Rails', rails_stub, transfer_nested_constants: true)
    rails_stub.root = Pathname.new(Dir.mktmpdir)
    rails_stub.logger = Logger.new(nil)
  end

  describe '.setup_rspec' do
    around do |test|
      original = ENV.fetch('CI', nil)
      ENV.delete('CI')
      test.run
    ensure
      ENV['CI'] = original
    end

    let(:fake_config) do
      Class.new do
        attr_reader :includes, :befores, :arounds

        def initialize
          @includes = []
          @befores = []
          @arounds = []
        end

        def include(mod, **options)
          @includes << [mod, options]
        end

        def before(*args, &block)
          @befores << [args, block]
        end

        def around(*args, &block)
          @arounds << [args, block]
        end
      end.new
    end

    it 'includes the screenshot helper and registers system hooks' do
      described_class.setup_rspec(fake_config)

      expect(fake_config.includes).to eq([[described_class::DocScreenshotHelper, { type: :system }]])
      expect(fake_config.befores.size).to eq(2)
      expect(fake_config.arounds.size).to eq(1)
    end

    it 'lengthens waits on contended machines' do
      ENV['CI'] = 'true'
      described_class.setup_rspec(fake_config)
      example = double
      allow(example).to receive(:driven_by)
      example.instance_exec(&fake_config.befores.first.last)
      expect(Capybara.default_max_wait_time).to eq(10)
    end

    it 'registered blocks delegate to the example setup methods' do
      described_class.setup_rspec(fake_config)
      example = double
      allow(example).to receive(:run)
      allow(described_class).to receive(:prepare_system_example)
      allow(described_class).to receive(:prepare_js_example)
      allow(described_class).to receive(:with_forgery_protection)

      fake_config.befores.each { |(_args, block)| example.instance_exec(&block) }
      fake_config.arounds.each { |(_args, block)| block.call(example) }

      expect(described_class).to have_received(:prepare_system_example).once
      expect(described_class).to have_received(:prepare_js_example).once
      expect(described_class).to have_received(:with_forgery_protection).once
    end
  end

  describe '.prepare_system_example' do
    let(:example) { double }

    around do |test|
      original = ENV.fetch('SCREENSHOTS', nil)
      test.run
    ensure
      ENV['SCREENSHOTS'] = original
    end

    it 'drives rack_test without SCREENSHOTS' do
      ENV['SCREENSHOTS'] = nil
      allow(example).to receive(:driven_by)

      described_class.prepare_system_example(example, 5, [1920, 900], {})

      expect(example).to have_received(:driven_by).with(:rack_test)
    end

    it 'drives the browser with SCREENSHOTS=true' do
      ENV['SCREENSHOTS'] = 'true'
      allow(described_class).to receive(:drive_with_browser)

      described_class.prepare_system_example(example, 5, [1920, 900], {})

      expect(described_class).to have_received(:drive_with_browser)
        .with(example, screen_size: [1920, 900], options: {})
    end
  end

  describe '.with_forgery_protection' do
    let(:base) { double }
    let(:example) { double }

    before do
      stub_const('ActionController', Module.new)
      stub_const('ActionController::Base', base)
      allow(base).to receive(:allow_forgery_protection=)
    end

    it 'enables protection around the example and disables after' do
      allow(example).to receive(:run)

      described_class.with_forgery_protection(example)

      expect(base).to have_received(:allow_forgery_protection=).with(true).ordered
      expect(example).to have_received(:run).ordered
      expect(base).to have_received(:allow_forgery_protection=).with(false).ordered
    end

    it 'disables protection even when the example raises' do
      allow(example).to receive(:run).and_raise('boom')

      expect { described_class.with_forgery_protection(example) }.to raise_error('boom')
      expect(base).to have_received(:allow_forgery_protection=).with(false)
    end
  end

  describe '.prepare_js_example' do
    let(:example) { double }

    it 'drives the browser and attaches logging for playwright' do
      described_class.configuration.browser_driver = :playwright
      allow(described_class).to receive(:drive_with_browser)
      allow(described_class).to receive(:attach_browser_logging)

      described_class.prepare_js_example(example, [1, 2], {})

      expect(described_class).to have_received(:drive_with_browser)
        .with(example, screen_size: [1, 2], options: {}).ordered
      expect(described_class).to have_received(:attach_browser_logging).with(example).ordered
    ensure
      described_class.configuration.browser_driver = :playwright
    end

    it 'skips playwright logging for selenium' do
      described_class.configuration.browser_driver = :selenium
      allow(described_class).to receive(:drive_with_browser)
      allow(described_class).to receive(:attach_browser_logging)

      described_class.prepare_js_example(example, [1, 2], {})

      expect(described_class).to have_received(:drive_with_browser)
        .with(example, screen_size: [1, 2], options: {})
      expect(described_class).not_to have_received(:attach_browser_logging)
    ensure
      described_class.configuration.browser_driver = :playwright
    end
  end

  describe '.drive_with_browser' do
    let(:example) { double }

    before do
      allow(example).to receive(:driven_by)
    end

    it 'drives playwright with screen size and options' do
      described_class.configuration.browser_driver = :playwright

      described_class.drive_with_browser(example, screen_size: [1, 2], options: { a: 1 })

      expect(example).to have_received(:driven_by).with(:playwright, screen_size: [1, 2], options: { a: 1 })
    ensure
      described_class.configuration.browser_driver = :playwright
    end

    it 'drives headless chrome for selenium' do
      described_class.configuration.browser_driver = :selenium

      described_class.drive_with_browser(example, screen_size: [1, 2], options: {})

      expect(example).to have_received(:driven_by).with(:selenium, using: :headless_chrome, screen_size: [1, 2])
    ensure
      described_class.configuration.browser_driver = :playwright
    end

    it 'raises for unknown drivers' do
      described_class.configuration.browser_driver = :webkit
      expect { described_class.drive_with_browser(example, screen_size: [1, 2], options: {}) }
        .to raise_error(ArgumentError, /webkit/)
    ensure
      described_class.configuration.browser_driver = :playwright
    end
  end

  describe '.driver_options' do
    it 'returns playwright timeouts for playwright' do
      described_class.configuration.browser_driver = :playwright
      expect(described_class.driver_options(7))
        .to eq(default_timeout: 7, default_navigation_timeout: 30)
    ensure
      described_class.configuration.browser_driver = :playwright
    end

    it 'returns no options for other drivers' do
      described_class.configuration.browser_driver = :selenium
      expect(described_class.driver_options(7)).to eq({})
    ensure
      described_class.configuration.browser_driver = :playwright
    end
  end

  describe '.attach_browser_logging' do
    let(:handlers) { {} }
    let(:playwright_page) { double }

    before do
      driver = double
      page = double(driver:)
      example = double(page:)
      allow(driver).to receive(:with_playwright_page).and_yield(playwright_page)
      allow(playwright_page).to receive(:on) { |event, handler| handlers[event] = handler }

      described_class.attach_browser_logging(example)
    end

    it 'logs console errors' do
      allow(rails_stub.logger).to receive(:error)

      handlers['console'].call(double(type: 'error', text: 'boom'))

      expect(rails_stub.logger).to have_received(:error).with('[BROWSER][error] boom')
    end

    it 'ignores non-error console messages' do
      allow(rails_stub.logger).to receive(:error)

      handlers['console'].call(double(type: 'info', text: 'hi'))

      expect(rails_stub.logger).not_to have_received(:error)
    end

    it 'logs page errors' do
      allow(rails_stub.logger).to receive(:error)

      handlers['pageerror'].call(double(message: 'bad'))

      expect(rails_stub.logger).to have_received(:error).with('[BROWSER][pageerror] bad')
    end
  end

  describe '.configuration' do
    it 'defaults to the conventional docs layout with the playwright driver' do
      expect(described_class.configuration).to have_attributes(
        docs_root: 'docs',
        generated_docs_dir: 'docs/platform-guide',
        screenshots_dir: 'docs/screenshots',
        specs_glob: 'spec/system/**/*_spec.rb',
        browser_driver: :playwright
      )
    end

    it 'is mutable through configure' do
      described_class.configure do |config|
        config.browser_driver = :selenium
      end
      expect(described_class.configuration.browser_driver).to eq(:selenium)
    ensure
      described_class.configuration.browser_driver = :playwright
    end

    it 'memoizes a single configuration object' do
      first = described_class.configuration
      expect(described_class.configuration).to be(first)
    end
  end

  describe 'VERSION' do
    it 'is a semantic version' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.load_engine' do
    def stub_rails_engine(initializers, rake_tasks)
      engine_base = Class.new do
        define_singleton_method(:initializer) { |*args, &block| initializers << [args, block] }
        define_singleton_method(:rake_tasks) { |&block| rake_tasks << block }

        def self.root
          Pathname.new(File.expand_path('../..', __dir__))
        end
      end
      stub_const('Rails', Module.new)
      stub_const('Rails::Engine', engine_base)
      # Pretend railties' engine file is already loaded so the require is a no-op.
      rails_engine_path = $LOAD_PATH.map { |dir| File.expand_path('rails/engine.rb', dir) }
                                    .find { |path| File.exist?(path) }
      $LOADED_FEATURES << rails_engine_path unless $LOADED_FEATURES.include?(rails_engine_path)
      engine_base
    end

    it 'loads the engine, registers view paths and rake tasks when Rails is present' do
      initializers = []
      rake_tasks = []
      engine_base = stub_rails_engine(initializers, rake_tasks)

      described_class.send(:load_engine)

      expect(AutoPlatformGuide::Engine.ancestors).to include(engine_base)
      expect(initializers.map(&:first)).to eq([['auto_platform_guide.view_paths', { before: :add_view_paths }]])

      app = double(config: double(paths: { 'app/views' => [] }))
      initializers.first.last.call(app)
      expect(app.config.paths['app/views']).to eq([engine_base.root.join('app', 'views')])

      expect(rake_tasks.size).to eq(1)
      rake_tasks.first.call
      expect(Rake::Task.task_defined?('auto_platform_guide:generate')).to be(true)
    end
  end

  describe 'DocScreenshotHelper#doc_screenshot' do
    subject(:host) { host_class.new }

    let(:host_class) do
      Class.new do
        include AutoPlatformGuide::DocScreenshotHelper

        attr_reader :saved

        def save_screenshot(path)
          @saved = path
        end
      end
    end

    around do |test|
      original = ENV.fetch('SCREENSHOTS', nil)
      test.run
    ensure
      ENV['SCREENSHOTS'] = original
    end

    it 'saves under screenshots_dir when enabled' do
      ENV['SCREENSHOTS'] = 'true'

      host.doc_screenshot('pages/home')

      expect(host.saved.to_s).to end_with('docs/screenshots/pages/home.png')
    end

    it 'does nothing when disabled' do
      ENV['SCREENSHOTS'] = nil

      expect(host.doc_screenshot('pages/home')).to be_nil
      expect(host.saved).to be_nil
    end
  end
end

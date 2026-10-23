# frozen_string_literal: true

require_relative 'lib/auto_platform_guide/version'

Gem::Specification.new do |spec|
  spec.name = 'auto-platform-guide'
  spec.version = AutoPlatformGuide::VERSION
  spec.authors = ['Mauricio Zaffari']
  spec.email = ['mauricio@develoz.com']

  spec.summary = 'Generate in-app documentation from system specs.'
  spec.description = 'Generator and spec helpers that turn doc comments and screenshots in system specs ' \
                     'into markdown platform guides, plus a markdown docs viewer for Rails admin apps.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.homepage = 'https://github.com/mauriciozaffari/auto-platform-guide'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'app/views/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.add_dependency 'actionpack', '>= 7.1'
  spec.add_dependency 'actionview', '>= 7.1'
  spec.add_dependency 'activemodel', '>= 7.1'
  # setup_rspec drives system specs through Capybara; the browser gems stay
  # host-provided (capybara-playwright-driver for :playwright, selenium-webdriver for :selenium).
  spec.add_dependency 'capybara', '>= 3.40'
  spec.add_dependency 'railties', '>= 7.1'
  spec.add_dependency 'redcarpet', '~> 3.6'
  spec.add_dependency 'rouge', '~> 5.0'
end

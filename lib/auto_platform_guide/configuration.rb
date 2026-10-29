# frozen_string_literal: true

module AutoPlatformGuide
  class Configuration
    # Where the viewer looks for markdown. The generator writes under
    # generated_docs_dir, which lives inside this directory.
    attr_accessor :docs_root
    # Where DocGenerator writes the generated guides (specs -> markdown).
    attr_accessor :generated_docs_dir
    # Where doc_screenshot writes PNGs.
    attr_accessor :screenshots_dir
    # Glob (relative to repo root) for specs searched for doc comments.
    attr_accessor :specs_glob
    # Browser driver used when a system spec needs a real browser:
    # :playwright (default) or :selenium.
    attr_accessor :browser_driver
    # Markdown written above the generated README table of contents. Defaults to
    # Generator::README_PREAMBLE when nil.
    attr_accessor :readme_preamble
    attr_accessor :locales
    # URL prefix where the docs viewer is mounted. Links, breadcrumbs and
    # wikilinks are built from it, so it must match the host's route.
    attr_reader :docs_path

    def initialize
      @docs_root = 'docs'
      @generated_docs_dir = 'docs/platform-guide'
      @screenshots_dir = 'docs/screenshots'
      @specs_glob = 'spec/system/**/*_spec.rb'
      @browser_driver = :playwright
      @readme_preamble = nil
      @locales = []
      @docs_path = '/docs'
    end

    def docs_path=(path)
      @docs_path = path.chomp('/')
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end

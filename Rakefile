# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'auto_platform_guide'

AutoPlatformGuide.configure do |config|
  config.specs_glob = 'spec/docs/**/*_spec.rb'
  config.readme_preamble = <<~MARKDOWN
    <h1 id="platform-guide">Platform Guide</h1>

    Usage and reference for the auto-platform-guide gem, generated from the
    documented specs in `spec/docs/`. Every page is rendered by the gem it
    describes: Redcarpet, Rouge, Mermaid, wikilinks and callouts.
  MARKDOWN
end

require 'auto_platform_guide/rake_tasks'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

# Auto Platform Guide

Generate in-app documentation from system specs.

- `AutoPlatformGuide::Generator` renders markdown guides from `# =` doc comments in
  system specs into `generated_docs_dir`, with an ordered README TOC grouped by
  `@category`/`@order` directives.
- `AutoPlatformGuide.setup_rspec(config)` wires system-spec screenshot support:
  `doc_screenshot('name')` captures to `screenshots_dir` when `SCREENSHOTS=true`,
  and specs run on `rack_test` unless they need a browser (`:js` tag or
  `SCREENSHOTS=true`). Browser driver is `:playwright` by default; set
  `config.browser_driver = :selenium` to use Selenium.
- The markdown viewer: `Document` + the `docs/show` template, rendered through
  `AutoPlatformGuide::DocsControllerActions`. Include it in the host app's docs
  controller so authentication stays application-owned:

  ```ruby
  class DocsController < AdminController
    include AutoPlatformGuide::DocsControllerActions
  end
  ```

  ```ruby
  # config/routes.rb
  get '/docs(/*id)', to: 'docs#show', as: 'docs'
  ```

  The shipped `docs/show` template expects host-provided pieces: a
  `content_header` helper, a `shared/_box` partial, `docs_path`, and a `docs`
  JavaScript asset.

## Installation

```ruby
# Gemfile
gem 'auto-platform-guide', github: 'mauriciozaffari/auto-platform-guide', branch: 'main'
```

Install from the repository; tagged releases also publish to RubyGems once a
release is cut.

## Setup

```ruby
# config/initializers/auto_platform_guide.rb
AutoPlatformGuide.configure do |config|
  config.docs_root = 'docs'
  config.generated_docs_dir = 'docs/platform-guide'
  config.screenshots_dir = 'docs/screenshots'
  config.specs_glob = 'spec/system/**/*_spec.rb'
  config.browser_driver = :playwright # or :selenium
end
```

The `:playwright` default needs `capybara-playwright-driver` in the host app;
`:selenium` needs `selenium-webdriver`. `capybara` itself is a gem dependency.
Note: `:selenium` support is unit-tested with mocked drivers — no CI job boots a
real browser under either driver.

```ruby
# spec/rails_helper.rb
require 'auto_platform_guide/rspec'

RSpec.configure do |config|
  AutoPlatformGuide.setup_rspec(config)
end
```

## Rake tasks

Generating docs is a rake task shipped with the gem. Rails apps load it through
the engine; anywhere else, require it from your `Rakefile`:

```ruby
require 'auto_platform_guide/rake_tasks'
```

```bash
rake auto_platform_guide:generate                      # all documented specs
rake "auto_platform_guide:generate[spec/foo_spec.rb]"  # one spec
rake auto_platform_guide:check                         # verify docs; non-zero when stale
rake auto_platform_guide:readme                        # rebuild the README TOC
rake auto_platform_guide:render                        # re-render, reuse screenshots on disk
```

## Tests

```bash
bin/setup
bundle exec rspec
```

# Auto Platform Guide

Generate in-app documentation from system specs.

The gem documents itself: `docs/platform-guide/` is generated from
`spec/docs/` by `rake auto_platform_guide:render` and checked in CI.

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

  The shipped `docs/show` template uses plain markup and inline JavaScript; it
  needs no host helpers, partials or assets. Links are built from `docs_path`, so
  set it to the path you mount (default `/docs`). Mermaid fenced blocks render
  when a global `mermaid` is present and stay readable as source otherwise.
  Override the template in the host app to change the surrounding chrome.

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
  config.docs_path = '/docs'
  config.generated_docs_dir = 'docs/platform-guide'
  config.screenshots_dir = 'docs/screenshots'
  config.specs_glob = 'spec/system/**/*_spec.rb'
  config.browser_driver = :playwright # or :selenium
  config.readme_preamble = nil
end
```

Every key is optional; the values above are the defaults. Keep
`generated_docs_dir` inside `docs_root`, since the viewer only reads from
`docs_root`.

The `:playwright` default needs `capybara-playwright-driver` in the host app;
`:selenium` needs `selenium-webdriver`. `capybara` itself is a gem dependency.
`readme_preamble` is markdown placed above the generated README's table of
contents; `nil` keeps `AutoPlatformGuide::Generator::README_PREAMBLE`. Note:
`:selenium` support is unit-tested with mocked drivers — no CI job boots a real
browser under either driver.

```ruby
# spec/rails_helper.rb
require 'auto_platform_guide/rspec'

RSpec.configure do |config|
  AutoPlatformGuide.setup_rspec(config)
end
```

## Writing a documented spec

Doc comments are parsed from the files matched by `specs_glob`. A spec file is
picked up when it has a `# = Heading` at column 0.

```ruby
# spec/system/orders_spec.rb
require 'rails_helper'

# @category Orders
# @order 200
#
# = Orders
# Create and track customer orders.
#
# == Creating an order
# Pick a customer, add line items and save.

RSpec.describe 'Orders', type: :system do
  it 'creates an order' do
    visit new_admin_order_path

    fill_in 'Reference', with: 'ORD-1'
    click_button 'Save'
    expect(page).to have_content('Order created')

    doc_screenshot('orders/created')
  end
end
```

- `# = Heading` renders as `<h1>`; every extra `=` adds a level (`# ==` → `<h2>`).
- Comment lines after a heading are its body, up to the next heading or the first
  non-comment line. Sections can also sit directly above the examples they describe.
- `@category` and `@order` only place the guide in the README TOC; they are
  stripped from the body. Specs without them fall under `Other` / `999_999`.
- The generator parses comments and embeds only screenshots whose PNG already
  exists on disk. `generate` runs the spec first to capture them; `render` and
  `check` never run specs.

`doc_screenshot('orders/created')` writes `docs/screenshots/orders/created.png`
when screenshots are enabled, and does nothing otherwise.

## Capturing screenshots

```bash
SCREENSHOTS=true bundle exec rspec spec/system/orders_spec.rb
rake auto_platform_guide:generate
```

`SCREENSHOTS=true` drives every system example in that run through the configured
browser (`:playwright` by default) and saves each `doc_screenshot` call. Without
it, system specs use `rack_test`; tag individual examples `:js` when only they
need a browser.

The helper is included for `type: :system` only, so keep that metadata. A
screenshot is rendered after the heading block that precedes its call.

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

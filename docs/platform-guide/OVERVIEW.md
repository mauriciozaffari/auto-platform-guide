<!--
Generated: 2026-10-29 19:16:19 UTC
-->

<h1 id="auto-platform-guide">Auto Platform Guide</h1>

Turn documented system specs into an in-app guide served at `docs_path`.


<h2 id="how-it-fits-together">How it fits together</h2>


```mermaid
flowchart LR
    spec["Documented spec"] --> generator["Generator"]
    generator --> markdown["docs/platform-guide/*.md"]
    markdown --> document["Document"]
    document --> viewer["docs/show"]
```

The generator parses `# =` comment blocks from the files matched by
`specs_glob` and writes one markdown file per spec. The viewer renders those
files with Redcarpet and Rouge and serves them through the host app's
controller.


<h2 id="install">Install</h2>


```ruby
# Gemfile
gem 'auto-platform-guide', '~> 0.1'
```


<h2 id="configure">Configure</h2>


Every setting is optional.

| Setting | Default | Purpose |
| --- | --- | --- |
| `docs_root` | `'docs'` | Root the viewer reads markdown from |
| `docs_path` | `'/docs'` | URL prefix for links, breadcrumbs and wikilinks |
| `generated_docs_dir` | `'docs/platform-guide'` | Where the generator writes guides |
| `screenshots_dir` | `'docs/screenshots'` | Where `doc_screenshot` saves PNGs |
| `specs_glob` | `'spec/system/**/*_spec.rb'` | Files scanned for doc comments |
| `browser_driver` | `:playwright` | Driver for specs that need a browser |
| `readme_preamble` | `nil` | Markdown above the README TOC; `nil` keeps the default |

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

The default preamble is `AutoPlatformGuide::Generator::README_PREAMBLE`. Set
`readme_preamble` to your own markdown to replace it.

> [!NOTE]
> `docs_root` is what `Document` reads; `generated_docs_dir` is where the
> generator writes. Keep the output inside the docs root or the viewer will
> not find it.

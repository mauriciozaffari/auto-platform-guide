<!--
Generated: 2026-10-23 02:16:30 UTC
-->

<h1 id="rake-tasks">Rake tasks</h1>

Shipped with the gem. Rails apps load them through the engine; anywhere else,
require them from the Rakefile.

```ruby
# Rakefile
require 'auto_platform_guide/rake_tasks'
```

| Task | What it does |
| --- | --- |
| `auto_platform_guide:generate` | Run every documented spec with `SCREENSHOTS=true`, then render |
| `auto_platform_guide:generate[spec]` | Run and render one spec |
| `auto_platform_guide:check` | Re-render from comments and fail when committed docs differ |
| `auto_platform_guide:readme` | Rebuild the README table of contents only |
| `auto_platform_guide:render` | Re-render bodies from comments, reusing screenshots on disk |

```bash
bundle exec rake auto_platform_guide:generate
bundle exec rake "auto_platform_guide:generate[spec/system/orders_spec.rb]"
bundle exec rake auto_platform_guide:check
```

`check` ignores the `Generated:` timestamp, so an unchanged guide always
matches. It exits non-zero and lists every stale guide.

> [!WARNING]
> `generate` runs specs and can be slow; use `render` when only the prose
> changed.

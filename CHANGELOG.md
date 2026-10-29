# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `locales` configuration: translated guides from per-spec `<spec>.<locale>.yml`
  files, a localized README, locale-specific screenshot directories (`DOC_LOCALE`),
  and a `check` that notices missing, mismatched or outdated translations.
- `localized_readme` configuration and an optional `category:` in translation
  files, so the translated README has translated texts, category names and
  diagram.

### Changed

- `Document#title` and breadcrumbs use the guide's first heading, falling back to
  the file name, so `EVENTS.pt-BR.md` no longer shows as "Events.Pt Br".
- `generate` now fails when a screenshot spec run fails, and shows that run's
  output, instead of silently ignoring the failure.

### Added

- `app/assets/stylesheets/auto_platform_guide/docs.css`, a minimal stylesheet
  for the docs pages, plus a styling guide covering the class contract and
  theming.
- `rails generate auto_platform_guide:styles`, which copies that stylesheet into
  the host app.
- Theme-aware `<picture>` images, so one image can follow the reader's colour
  scheme.

### Fixed

- A blockquote that followed a callout was rendered inside it, because Redcarpet
  folds blank-line-separated quotes into one callback.

## [0.1.0] - 2026-10-26

Initial release: spec-driven doc generator, `doc_screenshot` helper, configurable
browser driver wiring, and markdown docs viewer.

### Added

- Rake tasks for generating, checking, re-rendering and rebuilding the TOC,
  shipped with the gem.
- `readme_preamble` configuration for the markdown above the generated README
  table of contents.
- The gem's own guide in `docs/platform-guide/`, generated from `spec/docs/` and
  verified in CI.

### Changed

- Viewer links, breadcrumbs and wikilinks follow the `docs_path` configuration
  instead of hardcoding `/docs`.
- The docs viewer template no longer depends on host helpers, partials or
  assets (`content_header`, `shared/_box`, a host `docs_path` helper, `docs.js`).

### Fixed

- Doc comments preserve indentation beyond the `# ` prefix, so fenced code
  blocks keep their layout.
- Adjacent callout blockquotes render as separate callouts instead of one merged
  quote.

### Removed

- `bin/generate-docs`; use `auto_platform_guide:generate` instead.

[Unreleased]: https://github.com/mauriciozaffari/auto-platform-guide/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mauriciozaffari/auto-platform-guide/releases/tag/v0.1.0

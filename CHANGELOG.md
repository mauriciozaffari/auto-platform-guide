# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Rake tasks for generating, checking, re-rendering and rebuilding the TOC,
  shipped with the gem.

### Changed

- The docs viewer template no longer depends on host helpers, partials or
  assets (`content_header`, `shared/_box`, `docs_path`, `docs.js`).

### Removed

- `bin/generate-docs`; use `auto_platform_guide:generate` instead.

## [0.1.0] - 2026-10-06

- Initial release: spec-driven doc generator, doc_screenshot helper,
  configurable browser driver wiring, and markdown docs viewer.

[Unreleased]: https://github.com/mauriciozaffari/auto-platform-guide/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mauriciozaffari/auto-platform-guide/releases/tag/v0.1.0

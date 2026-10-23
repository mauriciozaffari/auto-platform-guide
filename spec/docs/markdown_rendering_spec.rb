# frozen_string_literal: true

# @category Reference
# @order 500
#
# = Markdown rendering
# Redcarpet parses and Rouge highlights. Fenced code, tables, autolinks and
# strikethrough are enabled, and a light Obsidian layer adds wikilinks and
# callouts on top.
#
# == Code
#
# ```ruby
# AutoPlatformGuide.configure do |config|
#   config.generated_docs_dir = 'docs/platform-guide'
# end
# ```
#
# ```javascript
# document.addEventListener('turbo:load', renderDiagrams)
# ```
#
# ```yaml
# auto_platform_guide:
#   docs_root: docs
#   specs_glob: spec/system/**/*_spec.rb
# ```
#
# == Mermaid
#
# ```mermaid
# sequenceDiagram
#     participant Spec
#     participant Generator
#     participant Viewer
#     Spec->>Generator: doc comments
#     Generator->>Viewer: markdown
#     Viewer->>Spec: /docs
# ```
#
# Mermaid blocks become `<pre class="mermaid">` and are never syntax-highlighted.
# A global `mermaid` object renders them in the viewer; without one the source
# stays readable.
#
# == Callouts
#
# > [!NOTE]
# > Neutral context.
#
# > [!TIP]
# > A shortcut.
#
# > [!IMPORTANT]
# > Something that matters.
#
# > [!WARNING]
# > Something that can break.
#
# > [!CAUTION]
# > Something destructive.
#
# == Tables
#
# | Feature | Value |
# | --- | --- |
# | Parser | Redcarpet |
# | Highlighter | Rouge |
# | Diagrams | Mermaid |
#
# == Links
#
# Standard markdown links work everywhere: [the overview](OVERVIEW.md) resolves
# in the viewer and on GitHub.
#
# The viewer also converts Obsidian-style wikilinks such as
# `[[OVERVIEW|the overview]]`, but other markdown readers, GitHub included, show
# them literally.

# frozen_string_literal: true

require 'digest'
require 'yaml'

module AutoPlatformGuide
  # A system spec file carrying `# = Heading` doc comments and
  # `doc_screenshot('name')` calls. Parses it once and exposes what the
  # generator needs: headings with their body, screenshots, TOC directives and
  # the doc title.
  class SpecFile
    # One `=` per heading level: `# = Title`, `# == Sub-title`.
    HEADING = /^\s*#\s*(=+)\s*(.+?)\s*$/
    # Exactly one space after `#` is the comment prefix; anything beyond it is
    # content, so indented code inside fenced blocks survives.
    COMMENT = /^\s*#\s?(.*?)\s*$/

    # `@category` / `@order` control TOC placement only and are stripped from the
    # body. `@order` is global across guides and categories sort by their
    # smallest `@order`, so there is no category list to keep in sync.
    CATEGORY_DIRECTIVE = /^\s*#\s*@category\s+(.+?)\s*$/
    ORDER_DIRECTIVE = /^\s*#\s*@order\s+(\d+)\s*$/
    DIRECTIVE = /^\s*#\s*@(?:category|order)\b/

    def initialize(path)
      @path = path
    end

    # True when the spec has at least one top-level doc comment.
    def documented?
      lines.any? { |line| line.match?(/^#\s*=/) }
    end

    # Comment blocks in source order: `{ level:, title:, content:, line_number: }`.
    # A block runs until the next heading or the first non-comment line;
    # `@category`/`@order` lines are TOC metadata, never body content.
    def doc_comments
      @doc_comments ||= parse_doc_comments
    end

    # Short fingerprint of the English doc comments. A translation file records it
    # as `source_digest`, so editing the English text flags the translation stale.
    def source_digest
      Digest::SHA256.hexdigest(doc_comments.map { |c| [c[:title], *c[:content]].join("\n") }.join("\n\n"))[0, 12]
    end

    # Translate each section while retaining its source line for screenshot placement.
    def translated_comments(locale)
      sections = translation(locale)['sections']

      doc_comments.zip(sections).map do |source, translated|
        source.merge(title: translated.fetch('title'), content: translated.fetch('body').lines.map(&:chomp))
      end
    end

    # The optional `category:` of a translation file, shown instead of `@category`.
    def translated_category(locale)
      translation(locale)['category']
    end

    # `{ path:, line_number: }` for every `doc_screenshot('...')` call.
    def screenshot_calls
      @screenshot_calls ||= parse_screenshot_calls
    end

    # First `@category` / `@order` in the file, or nil.
    def directives
      @directives ||= { category: first_match(CATEGORY_DIRECTIVE), order: first_match(ORDER_DIRECTIVE)&.to_i }
    end

    # The top-level (`# =`, not `# ==`) heading, falling back to the file name.
    def title
      @title ||= lines.filter_map { |line| line.match(/^\s*#\s*=(?!=)\s*(.+?)\s*$/)&.[](1)&.strip }
                      .reject(&:empty?).first ||
                 File.basename(@path, '_spec.rb').split('_').map(&:capitalize).join(' ')
    end

    private

    def lines
      @lines ||= File.readlines(@path, encoding: 'UTF-8')
    end

    # The parsed and validated `<spec>.<locale>.yml`.
    def translation(locale)
      path = @path.sub(/\.rb\z/, ".#{locale}.yml")
      raise ArgumentError, "Missing translation file #{path}" unless File.file?(path)

      data = YAML.safe_load_file(path)
      sections = data.is_a?(Hash) ? data['sections'] : nil
      raise ArgumentError, "#{path} needs a `sections` list" unless sections.is_a?(Array)
      unless sections.size == doc_comments.size
        raise ArgumentError,
              "#{path} has #{sections.size} sections, #{@path} has #{doc_comments.size}"
      end
      unless data['source_digest'] == source_digest
        raise ArgumentError,
              "#{path} is out of date: set `source_digest: #{source_digest}` after updating it"
      end

      data
    end

    def first_match(pattern)
      lines.filter_map { |line| line.match(pattern)&.[](1) }.first
    end

    def parse_doc_comments
      blocks = []
      current = nil

      lines.each.with_index(1) do |line, number|
        next if DIRECTIVE.match?(line)

        if (heading = line.match(HEADING))
          blocks << current if current
          title = heading[2].strip
          # A divider line like `# ==== ` has no title and is not a heading.
          current = title.empty? ? nil : { level: heading[1].length, title:, content: [], line_number: number }
        elsif current.nil?
          next
        elsif (comment = line.match(COMMENT))
          current[:content] << comment[1]
        else
          blocks << current
          current = nil
        end
      end

      blocks << current if current
      blocks
    end

    def parse_screenshot_calls
      call = %r{doc_screenshot\(['"]([\w\-/]+)['"]\)}

      lines.each.with_index(1).filter_map do |line, number|
        path = line[call, 1]
        { path:, line_number: number } if path
      end
    end
  end
end

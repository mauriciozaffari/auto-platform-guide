# frozen_string_literal: true

require 'erb'
require 'pathname'
require 'redcarpet'
require 'rouge'
require 'active_model'
require 'action_view'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/string/inflections'

module AutoPlatformGuide
  # A markdown document under the configured docs root, rendered for /docs.
  class Document
    include ActiveModel::Model

    class RecordNotFound < StandardError; end

    FOLDER_INDEX_NAMES = ['README', '00 - Index'].freeze
    H1 = %r{\A\s*<h1[^>]*>(.*?)</h1>}

    class Renderer < Redcarpet::Render::HTML
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::SanitizeHelper

      # Obsidian wikilink: [[Note]], [[Note#Heading]], [[Note|Alias]] (and combinations).
      WIKILINK = /\[\[([^\]#|]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]/
      CALLOUT = /\A<p>\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:<br>\s*)?/i
      CALLOUT_ICONS = {
        'note' => 'info-circle',
        'tip' => 'lightbulb-o',
        'important' => 'exclamation-circle',
        'warning' => 'warning',
        'caution' => 'ban'
      }.freeze

      # Redcarpet merges adjacent blockquotes into one callback, so split the
      # quote at each callout marker and render them separately.
      CALLOUT_SPLIT = /(?=<p>\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\])/i

      def self.render(path, base_dir: nil)
        new(base_dir:).render(path)
      end

      def initialize(base_dir: nil, docs_path: nil, **options)
        @base_dir = base_dir
        @docs_path = (docs_path || Document.docs_path).chomp('/')
        super(options.merge(with_toc_data: true, hard_wrap: true))
      end

      def sanitize(html)
        tags = ActionView::Base.sanitized_allowed_tags + %w[table thead tbody th tr td img i]
        attributes = ActionView::Base.sanitized_allowed_attributes + %w[style colspan src alt id class aria-hidden]
        super(html, tags:, attributes:)
      end

      def markdown
        @markdown ||= Redcarpet::Markdown.new(
          self,
          fenced_code_blocks: true,
          tables: true,
          autolink: true,
          strikethrough: true
        )
      end

      def render(path)
        sanitize(markdown.render(File.read(path)))
      end

      # Convert Obsidian wikilinks to markdown links before parsing, leaving any
      # text inside fenced or inline code untouched.
      def preprocess(document)
        replace_wikilinks(document)
      end

      def block_code(code, language)
        # Mermaid diagrams are rendered client-side: emit the raw source in a
        # <pre class="mermaid"> for mermaid.js, never syntax-highlighted.
        return content_tag(:pre, code, class: 'mermaid') if language == 'mermaid'

        lexer = Rouge::Lexer.find_fancy(language.to_s, code) || Rouge::Lexers::PlainText.new
        formatter = Rouge::Formatters::HTMLInline.new(Rouge::Themes::Github.mode(:dark).new)
        code = formatter.format(lexer.lex(code))
        content_tag(:pre, class: 'code-block') do
          content_tag(:code, sanitize(code), class: "language-#{lexer.tag}")
        end
      end

      def image(link, title, alt_text)
        # tag.img renders HTML5 without the self-closing slash the specs assert.
        tag(:img, src: link, alt: alt_text, title:, class: 'img-responsive') # rubocop:disable Rails/ContentTag
      end

      def block_quote(quote)
        quote.split(CALLOUT_SPLIT).reject(&:empty?).map { |segment| render_quote(segment) }.join("\n")
      end

      private

      def render_quote(segment)
        callout = segment.match(CALLOUT)
        return %(<blockquote>#{segment}</blockquote>) unless callout

        type = callout[1].downcase
        body = segment.sub(CALLOUT, '<p>')
        icon = tag.i(class: "fa fa-#{CALLOUT_ICONS.fetch(type)}", aria: { hidden: true })
        title = %(<p class="callout-title">#{icon} #{type.titleize}</p>)

        %(<blockquote class="callout callout-#{type}">#{title}\n#{body}</blockquote>)
      end

      def replace_wikilinks(document)
        in_fence = false

        document.each_line.map do |line|
          if line.start_with?('```')
            in_fence = !in_fence
            line
          elsif in_fence
            line
          else
            replace_wikilinks_in_line(line)
          end
        end.join
      end

      def replace_wikilinks_in_line(line)
        line.split(/(`[^`]*`)/).map do |part|
          if part.start_with?('`')
            part
          else
            part.gsub(WIKILINK) do
              wikilink_markdown(::Regexp.last_match(1), ::Regexp.last_match(2), ::Regexp.last_match(3))
            end
          end
        end.join
      end

      def wikilink_markdown(name, heading, alias_text)
        name = name.strip
        label = alias_text&.strip
        label ||= heading ? "#{name} › #{heading.strip}" : name
        "[#{escape_markdown(label)}](#{wikilink_url(name, heading)})"
      end

      # Escape characters the link label would otherwise trigger as markdown
      # (emphasis, links, code) so snake_case names render literally.
      def escape_markdown(text)
        text.gsub(/[\\_*\[\]`]/) { |char| "\\#{char}" }
      end

      def wikilink_url(name, heading)
        segments = [@base_dir, name].compact_blank
        url = "#{@docs_path}/#{segments.map { |segment| ERB::Util.url_encode(segment) }.join('/')}"
        url += "##{heading_anchor(heading)}" if heading
        url
      end

      # Mirror Redcarpet's with_toc_data anchor generation for [[Note#Heading]]:
      # drop non-alphanumerics (underscores included), then collapse whitespace to "-".
      def heading_anchor(heading)
        heading.strip.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '-').gsub(/^-|-$/, '')
      end
    end

    attr_reader :id, :name, :path

    class << self
      def where(folder: nil, name: nil)
        prefix = folder ? "#{docs_root}/#{folder}/" : "{#{docs_root}/**/,}"
        Rails.root.glob("#{prefix}#{name || '*'}.md").sort.map { |path| new(path) }
      end

      alias all where
      delegate :first, :last, to: :where

      def find(name)
        # .lazy stops at the first index file that exists.
        where(name:).first ||
          FOLDER_INDEX_NAMES.lazy.filter_map { |index| where(folder: name, name: index).first }.first ||
          raise(RecordNotFound, "Couldn't find document #{name}")
      end

      def docs_root
        AutoPlatformGuide.configuration.docs_root
      end

      def docs_path
        AutoPlatformGuide.configuration.docs_path
      end
    end

    def initialize(path)
      @path = path
      relative_path = Pathname(path).relative_path_from(Rails.root).to_s
      prefix = Regexp.escape(AutoPlatformGuide.configuration.docs_root)
      @id = relative_path.match(%r{\A(?:#{prefix}/)?(?<id>.*)\.md\z})&.[](:id)
      @name = File.basename(path, '.md')
    end

    def render
      dir = File.dirname(id)
      Renderer.render(path, base_dir: dir == '.' ? nil : dir)
    end

    # The guide's first heading (already translated in localized guides), else the file name.
    def title
      heading = File.file?(path) ? File.foreach(path, encoding: 'UTF-8').filter_map { |line| line[H1, 1] }.first : nil
      heading.presence || name.titleize
    end

    def breadcrumbs
      parts = id.split('/')

      parts.each_with_index.map do |part, i|
        { name: i == parts.size - 1 ? title : part.titleize, path: "#{self.class.docs_path}/#{parts[0..i].join('/')}" }
      end
    end
  end
end

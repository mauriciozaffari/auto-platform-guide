# frozen_string_literal: true

require 'yaml'

module AutoPlatformGuide
  # The ordered guides of one locale. The generator builds one from the spec
  # directives and writes it as `toc.yml`; a host app loads the committed file to
  # navigate between guides, and the README sections are rendered from `#groups`.
  class TableOfContents
    # One guide in the table of contents.
    class Entry
      attr_reader :id, :title, :category

      def initialize(id:, title:, category:)
        @id = id
        @title = title
        @category = category
      end

      def to_h
        { 'id' => id, 'title' => title, 'category' => category }
      end
    end

    # Reads the committed toc for a locale, falling back to English when the
    # locale has none.
    def self.load(locale: nil)
      path = path_for(locale)
      path = path_for(nil) unless File.exist?(path)
      entries = YAML.load_file(path).map do |entry|
        Entry.new(id: entry['id'], title: entry['title'], category: entry['category'])
      end
      new(entries, locale:)
    end

    # Where a locale's toc is written.
    def self.path_for(locale)
      File.join(AutoPlatformGuide.configuration.generated_docs_dir, locale ? "toc.#{locale}.yml" : 'toc.yml')
    end

    def initialize(entries, locale: nil)
      @entries = entries
      @locale = locale
    end

    attr_reader :entries, :locale

    # Guides by category, in the order the categories first appear.
    def groups
      entries.group_by(&:category)
    end

    # The guides either side of `id`, e.g. `{ previous: Entry, next: Entry }`.
    # Omits a side that has no neighbour and returns `{}` for an unknown guide.
    def neighbours(id)
      sequence[id] || {}
    end

    def write
      File.write(self.class.path_for(locale), to_yaml)
    end

    def stale?
      File.read(self.class.path_for(locale), encoding: 'UTF-8') != to_yaml
    rescue Errno::ENOENT
      true
    end

    def to_yaml
      entries.map(&:to_h).to_yaml
    end

    private

    def sequence
      @sequence ||= [nil, *entries, nil].each_cons(3).to_h do |previous, entry, following|
        [entry.id, { previous:, next: following }.compact]
      end
    end
  end
end

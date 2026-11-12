# frozen_string_literal: true

require 'yaml'

module AutoPlatformGuide
  # Ordered guides for a locale, read from the `toc.yml` the generator writes
  # next to the README. Lets a host app build previous/next navigation from
  # generated data, without parsing the README or reading specs at runtime.
  class TableOfContents
    Entry = Data.define(:id, :title)

    # Entries around `id` for a locale, e.g. `{ previous: Entry, next: Entry }`.
    def self.neighbours(id, locale: nil)
      new(locale:).neighbours(id)
    end

    def initialize(locale: nil)
      @locale = locale
    end

    def entries
      @entries ||= YAML.load_file(path).map do |entry|
        Entry.new(id: entry.fetch('id'), title: entry.fetch('title'))
      end
    end

    # Omits a side that has no neighbour and returns `{}` for an unknown guide.
    def neighbours(id)
      sequence[id] || {}
    end

    private

    attr_reader :locale

    def sequence
      @sequence ||= [nil, *entries, nil].each_cons(3).to_h do |previous, entry, following|
        [entry.id, { previous:, next: following }.compact]
      end
    end

    def path
      directory = AutoPlatformGuide.configuration.generated_docs_dir
      localized = File.join(directory, "toc.#{locale}.yml")
      locale && File.exist?(localized) ? localized : File.join(directory, 'toc.yml')
    end
  end
end

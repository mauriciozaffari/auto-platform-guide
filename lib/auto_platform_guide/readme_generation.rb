# frozen_string_literal: true

module AutoPlatformGuide
  # Writes the README table of contents and the machine-readable toc files the
  # docs viewer navigation reads, for the English run and every locale.
  module ReadmeGeneration
    private

    # Writes the README table of contents grouped by `@category` and ordered by
    # `@order`. Called at the end of a full/partial generation run and standalone
    # via `regenerate_readme` (the `--readme-only` mode).
    def generate_readme
      write_readme(nil)
    end

    # Ordered guides for a locale, as written to `toc.yml` next to the README.
    # Host apps read it through TableOfContents to build navigation without
    # parsing the README or reading specs at runtime.
    def table_of_contents(locale = nil)
      toc_groups(locale).flat_map(&:last).map do |entry|
        id = entry[:file].delete_suffix('.md')
        id = id.delete_suffix(".#{locale}") if locale
        { 'id' => id, 'title' => entry[:title] }
      end
    end

    def write_readme(locale)
      File.write(readme_path(locale), "#{timestamp_header}#{readme_body(locale)}")
      File.write(toc_path(locale), table_of_contents(locale).to_yaml)
    end

    def readme_path(locale)
      File.join(config.generated_docs_dir, locale ? "README.#{locale}.md" : 'README.md')
    end

    def toc_path(locale)
      File.join(config.generated_docs_dir, locale ? "toc.#{locale}.yml" : 'toc.yml')
    end

    # The README markdown after the timestamp header. With a locale it uses the
    # translated titles and category names, and `localized_readme[locale]`
    # (`'preamble'`, `'contents'`) for the fixed texts, falling back to English.
    def readme_body(locale = nil)
      texts = config.localized_readme.fetch(locale.to_s, {})
      out = StringIO.new

      out.write(texts['preamble'] || config.readme_preamble || Generator::README_PREAMBLE)

      # Build the TOC from every documented spec (not just the ones regenerated
      # in this run) so running for a subset of specs doesn't drop other
      # entries. Group by `@category` and order by `@order`.
      groups = toc_groups(locale)

      out.puts category_workflow_diagram(groups.map(&:first))
      out.puts
      out.puts %(<h2 id="table-of-contents">#{texts['contents'] || 'Table of Contents'}</h2>)

      groups.each { |category, entries| out.write(toc_section(category, entries)) }

      out.string
    end

    def toc_section(category, entries)
      links = entries.map { |entry| "- [#{entry[:title]}](#{entry[:file]})\n" }.join
      %(\n<h3 id="#{slugify(category)}">#{category}</h3>\n\n#{links})
    end

    # A Mermaid flowchart of the guide categories in workflow order, rendered by
    # the in-app docs viewer. Derived from the same ordered categories as the TOC,
    # so it never drifts from the actual guides.
    def category_workflow_diagram(categories)
      return '' if categories.empty?

      nodes = categories.each_with_index.map { |category, index| %(c#{index}["#{category}"]) }
      <<~DIAGRAM.chomp

        ```mermaid
        flowchart LR
            #{nodes.join(' --> ')}
        ```
      DIAGRAM
    end

    # Returns the TOC as an ordered list of [category, entries] pairs.
    # Category order is derived entirely from the specs: categories are
    # listed in ascending order of the smallest `@order` they contain (ties broken
    # alphabetically), and entries within a category are ordered by `@order` then
    # title. Only specs whose generated doc actually exists on disk are linked.
    def toc_groups(locale = nil)
      entries = find_documented_specs.filter_map do |spec_file|
        file = File.basename(generate_output_filename(spec_file))
        next unless File.exist?(File.join(config.generated_docs_dir, file))

        toc_entry(spec_file, file, locale)
      end

      groups = entries.group_by { |entry| entry[:category] }
                      .sort_by { |category, group| [group.map { |entry| entry[:order] }.min, category] }
      groups.map do |category, group|
        [localized_category(group, category), group.sort_by { |entry| [entry[:order], entry[:title]] }]
      end
    end
  end
end

# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module AutoPlatformGuide
  # Generates markdown guides from system specs with doc comments, plus the
  # README table of contents. Doc comments are `# = Heading` blocks in spec
  # files; `doc_screenshot('name')` calls reference PNGs captured during a
  # SCREENSHOTS=true run.
  class Generator
    include LocalizedGeneration

    # Fallbacks for specs that omit the directives below. Specs with no
    # `@category` collect under DEFAULT_CATEGORY; specs with no `@order` sort
    # after numbered ones. Both defaults push such docs to the end of the TOC.
    DEFAULT_CATEGORY = 'Other'
    DEFAULT_ORDER = 999_999

    FLAGS = %w[--check --readme-only --render-only].freeze

    README_PREAMBLE = <<~MARKDOWN
      <h1 id="platform-guide">Platform Guide</h1>

      This guide is the primary, automatically generated reference for this
      application. It is extracted from documented specs, so every page reflects
      behaviour that is actually tested in the codebase.

      Guides are grouped by area below and ordered to follow a typical workflow, from
      the first area through to the last.
    MARKDOWN

    # Returns a process exit status (0 ok, 1 stale in --check mode).
    # The bin wrapper passes it straight to exit.
    def self.run(argv)
      spec_files = argv - FLAGS
      generator = new(spec_files.empty? ? nil : spec_files)

      run_mode(generator, FLAGS.find { |flag| argv.include?(flag) })
    rescue ArgumentError => e
      warn "✗ #{e.message}"
      1
    end

    def self.run_mode(generator, flag)
      case flag
      when '--check'
        # Verify docs without running specs; used by CI.
        generator.up_to_date? ? 0 : 1
      when '--readme-only'
        # Rebuild the TOC from committed docs + spec directives only (fast).
        generator.regenerate_readme
        0
      when '--render-only'
        # Re-render doc bodies from doc comments using screenshots on disk.
        generator.generate(run_specs: false)
        0
      else
        generator.generate
        0
      end
    end

    def initialize(spec_files = nil)
      @spec_files = spec_files || find_documented_specs
    end

    def config
      AutoPlatformGuide.configuration
    end

    def generate(run_specs: true)
      if @spec_files.empty?
        puts 'No system specs with documentation comments found.'
        return
      end

      validate_translations
      @spec_files.each do |spec_file|
        puts "\nGenerating documentation for #{spec_file}..."
        process_spec(spec_file, run_specs:)
      end

      generate_readme
      config.locales.each { |locale| generate_translation(locale) }

      puts "\n✓ Documentation generation complete!"
      puts "  Generated #{@spec_files.size} documentation file(s) in #{config.generated_docs_dir}/"
      puts '  Generated README.md with table of contents'
    end

    # Verify the committed docs are in sync with their documented specs,
    # without running the specs. Re-renders the doc body and compares against
    # the committed markdown, ignoring the generation timestamp and the
    # screenshot binaries themselves. Returns true when everything is up to date.
    def up_to_date?
      stale = find_documented_specs.select { |spec_file| doc_stale?(spec_file) || translations_stale?(spec_file) }
      readme_stale = stale.empty? && readmes_stale?
      unless stale.any? || readme_stale
        puts '✓ Platform-guide docs are up to date.'
        return true
      end

      warn '✗ Localized README is out of date; run rake auto_platform_guide:readme' if readme_stale
      report_stale(stale)
      false
    end

    # Rebuild only the README table of contents from the committed docs and
    # their spec `@category`/`@order` directives, without running any specs.
    def regenerate_readme
      validate_translations
      generate_readme
      config.locales.each { |locale| translate_readme(locale) }
      puts '✓ Regenerated README.md table of contents.'
    end

    private

    def report_stale(stale)
      return if stale.empty?

      warn "✗ Platform-guide docs are out of date for #{stale.size} spec(s):"
      stale.each { |spec_file| warn "  - #{spec_file} -> #{generate_output_filename(spec_file)}" }
      warn ''
      warn 'Regenerate the affected guide(s) and commit the result:'
      stale.each { |spec_file| warn %(  rake "auto_platform_guide:generate[#{spec_file}]") }
    end

    def doc_stale?(spec_file)
      output_file = generate_output_filename(spec_file)
      return true unless File.exist?(output_file)

      expected = "#{render_doc_body(spec(spec_file).doc_comments, spec(spec_file).screenshot_calls).rstrip}\n"
      committed = strip_timestamp_header(File.read(output_file, encoding: 'UTF-8'))
      expected != committed
    end

    def strip_timestamp_header(content)
      content.sub(/\A<!--\nGenerated: [^\n]*\n-->\n\n/, '')
    end

    def find_documented_specs
      Dir.glob(config.specs_glob).select { |file| spec(file).documented? }
    end

    # Parsed spec, memoized so a run reads each file once.
    def spec(spec_file)
      @specs ||= {}
      @specs[spec_file] ||= SpecFile.new(spec_file)
    end

    def process_spec(spec_file, run_specs: true)
      parsed = spec(spec_file)

      if run_specs
        puts '  Running spec with SCREENSHOTS=true...'
        run_spec_with_screenshots(spec_file)
      else
        puts '  Re-rendering from doc comments (using existing screenshots)...'
      end

      # Generate markdown file
      output_file = generate_output_filename(spec_file)
      generate_markdown(output_file, parsed.doc_comments, parsed.screenshot_calls)

      puts "  ✓ Generated #{output_file}"
    end

    def run_spec_with_screenshots(spec_file)
      FileUtils.mkdir_p(config.screenshots_dir)

      command = ['bundle', 'exec', 'rspec', '--format', 'documentation', spec_file]
      raise "Screenshot capture failed: #{spec_file}" unless system({ 'SCREENSHOTS' => 'true' }, *command)

      config.locales.each do |locale|
        env = { 'SCREENSHOTS' => 'true', 'DOC_LOCALE' => locale.to_s }
        raise "Screenshot capture failed: #{spec_file} (#{locale})" unless system(env, *command)
      end
    end

    def generate_output_filename(spec_file)
      basename = File.basename(spec_file, '_spec.rb')
      output_name = "#{basename.upcase.tr('_', '-')}.md"
      File.join(config.generated_docs_dir, output_name)
    end

    def generate_markdown(output_file, doc_comments, screenshot_calls)
      FileUtils.mkdir_p(config.generated_docs_dir)
      File.write(output_file, "#{timestamp_header}#{render_doc_body(doc_comments, screenshot_calls).rstrip}\n")
    end

    def timestamp_header
      "<!--\nGenerated: #{generated_at}\n-->\n\n"
    end

    def generated_at
      Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')
    end

    # Render the markdown body (everything after the timestamp header) from a
    # spec's doc comments and screenshot calls. Shared by generation and --check
    # so both produce byte-identical output for the same spec.
    def render_doc_body(doc_comments, screenshot_calls, locale: nil)
      body = +''

      doc_comments.each_with_index do |comment, index|
        heading_tag = "h#{comment[:level]}"
        heading_id = slugify(comment[:title])
        body << "<#{heading_tag} id=\"#{heading_id}\">#{comment[:title]}</#{heading_tag}>\n\n"

        comment[:content].each { |line| body << "#{line}\n" }
        body << "\n"

        next_comment_line = doc_comments[index + 1]&.dig(:line_number) || Float::INFINITY
        screenshots = find_related_screenshots(comment[:line_number], next_comment_line, screenshot_calls)
        screenshots.each do |screenshot|
          rendered = render_screenshot(screenshot[:path], locale:)
          body << rendered if rendered
        end
      end

      body
    end

    def find_related_screenshots(current_line, next_line, screenshot_calls)
      # Find screenshots that appear after this comment but before the next one
      screenshot_calls.select do |screenshot|
        screenshot[:line_number] > current_line && screenshot[:line_number] < next_line
      end
    end

    def render_screenshot(screenshot_path, locale: nil)
      directory = [config.screenshots_dir, locale].compact.join('/')
      return unless File.exist?(File.join(directory, "#{screenshot_path}.png"))

      prefix = "/#{directory.sub(%r{\A/+}, '').sub(%r{/+\z}, '')}"
      "![#{screenshot_path}](#{prefix}/#{screenshot_path}.png)\n\n"
    end

    def slugify(text)
      text.downcase
          .gsub(/[^a-z0-9\s-]/, '')
          .gsub(/\s+/, '-').squeeze('-')
          .gsub(/^-|-$/, '')
    end

    # Writes the README table of contents grouped by `@category` and ordered by
    # `@order`. Called at the end of a full/partial generation run and standalone
    # via `regenerate_readme` (the `--readme-only` mode).
    def generate_readme
      readme_path = File.join(config.generated_docs_dir, 'README.md')

      File.open(readme_path, 'w') do |f|
        f.puts '<!--'
        f.puts "Generated: #{generated_at}"
        f.puts '-->'
        f.puts

        f.write(config.readme_preamble || README_PREAMBLE)

        # Build the TOC from every documented spec (not just the ones regenerated
        # in this run) so running for a subset of specs doesn't drop other
        # entries. Group by `@category` and order by `@order`.
        groups = toc_groups

        f.puts category_workflow_diagram(groups.map(&:first))
        f.puts
        f.puts '<h2 id="table-of-contents">Table of Contents</h2>'

        groups.each do |category, entries|
          f.puts
          f.puts %(<h3 id="#{slugify(category)}">#{category}</h3>)
          f.puts
          entries.each do |entry|
            f.puts "- [#{entry[:title]}](#{entry[:file]})"
          end
        end
      end
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
    def toc_groups
      entries = find_documented_specs.filter_map do |spec_file|
        file = File.basename(generate_output_filename(spec_file))
        next unless File.exist?(File.join(config.generated_docs_dir, file))

        parsed = spec(spec_file)
        directives = parsed.directives
        {
          file:,
          title: parsed.title,
          category: directives[:category] || DEFAULT_CATEGORY,
          order: directives[:order] || DEFAULT_ORDER
        }
      end

      entries
        .group_by { |entry| entry[:category] }
        .sort_by { |category, group| [group.map { |entry| entry[:order] }.min, category] }
        .map { |category, group| [category, group.sort_by { |entry| [entry[:order], entry[:title]] }] }
    end
  end
end

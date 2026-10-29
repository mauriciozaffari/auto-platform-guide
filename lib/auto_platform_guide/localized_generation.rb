# frozen_string_literal: true

module AutoPlatformGuide
  # Localized counterparts for generated guides: `<spec>.<locale>.yml` holds the
  # translated sections and `SOME-GUIDE.<locale>.md` is what gets generated.
  module LocalizedGeneration
    private

    def translations_stale?(spec_file)
      config.locales.any? { |locale| translation_stale?(spec_file, locale) }
    end

    def translation_stale?(spec_file, locale)
      path = translated_filename(spec_file, locale)
      return true unless File.file?(path)

      parsed = spec(spec_file)
      expected = "#{render_doc_body(parsed.translated_comments(locale), parsed.screenshot_calls, locale:).rstrip}\n"
      strip_timestamp_header(File.read(path, encoding: 'UTF-8')) != expected
    rescue ArgumentError
      true
    end

    def readmes_stale?
      config.locales.any? { |locale| readme_stale?(locale) }
    end

    def readme_stale?(locale)
      committed = strip_timestamp_header(File.read(translated_readme_path(locale), encoding: 'UTF-8'))
      committed != readme_body(locale)
    rescue Errno::ENOENT
      true
    end

    # Fail before writing anything when a translation is missing or outdated.
    def validate_translations
      find_documented_specs.product(config.locales).each do |spec_file, locale|
        spec(spec_file).translated_comments(locale)
      end
    end

    def translated_filename(spec_file, locale)
      generate_output_filename(spec_file).sub(/\.md\z/, ".#{locale}.md")
    end

    def generate_translation(locale)
      @spec_files.each do |file|
        parsed = spec(file)
        body = render_doc_body(parsed.translated_comments(locale), parsed.screenshot_calls, locale:)
        File.write(translated_filename(file, locale), "#{timestamp_header}#{body.rstrip}\n")
      end
      translate_readme(locale)
    end

    def toc_entry(spec_file, file, locale)
      parsed = spec(spec_file)
      directives = parsed.directives
      {
        file: locale ? file.sub(/\.md\z/, ".#{locale}.md") : file,
        title: locale ? parsed.translated_comments(locale).first.fetch(:title) : parsed.title,
        category: directives[:category] || Generator::DEFAULT_CATEGORY,
        translated_category: locale ? parsed.translated_category(locale) : nil,
        order: directives[:order] || Generator::DEFAULT_ORDER
      }
    end

    # Group name: the first translated `category:` of its guides, else the English one.
    def localized_category(group, category)
      group.filter_map { |entry| entry[:translated_category] }.first || category
    end

    def translate_readme(locale)
      File.write(translated_readme_path(locale), "#{timestamp_header}#{readme_body(locale)}")
    end

    def translated_readme_path(locale)
      File.join(config.generated_docs_dir, "README.#{locale}.md")
    end
  end
end

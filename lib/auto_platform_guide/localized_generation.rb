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
      config.locales.any? { |locale| translated_readme_content(locale) != File.read(translated_readme_path(locale)) }
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

    def translate_readme(locale)
      File.write(translated_readme_path(locale), translated_readme_content(locale))
    end

    def translated_readme_path(locale)
      File.join(config.generated_docs_dir, "README.#{locale}.md")
    end

    def translated_readme_content(locale)
      source = File.read(File.join(config.generated_docs_dir, 'README.md'))
      find_documented_specs.each do |file|
        parsed = spec(file)
        title = parsed.translated_comments(locale).first.fetch(:title)
        source = source.gsub("[#{parsed.title}](#{File.basename(generate_output_filename(file))})",
                             "[#{title}](#{File.basename(translated_filename(file, locale))})")
      end
      source
    end
  end
end

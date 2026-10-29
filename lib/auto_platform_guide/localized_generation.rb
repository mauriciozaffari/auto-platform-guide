# frozen_string_literal: true

module AutoPlatformGuide
  # Localized counterparts for generated guides.
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
    rescue Errno::ENOENT, KeyError, ArgumentError
      true
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
      source = File.read(File.join(config.generated_docs_dir, 'README.md'))
      find_documented_specs.each do |file|
        parsed = spec(file)
        translated = parsed.translated_comments(locale).first.fetch(:title)
        source = source.gsub("[#{parsed.title}](#{File.basename(generate_output_filename(file))})",
                             "[#{translated}](#{File.basename(translated_filename(file, locale))})")
      end
      File.write(File.join(config.generated_docs_dir, "README.#{locale}.md"), source)
    end
  end
end

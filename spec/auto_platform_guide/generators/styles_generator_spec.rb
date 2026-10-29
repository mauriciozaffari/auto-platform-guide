# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'rails/generators'
require 'generators/auto_platform_guide/styles/styles_generator'

RSpec.describe AutoPlatformGuide::Generators::StylesGenerator do
  it 'is found by the generator lookup as auto_platform_guide:styles' do
    Dir.mktmpdir do |root|
      Rails::Generators.invoke('auto_platform_guide:styles', [], destination_root: root)

      copied = File.join(root, 'app/assets/stylesheets/docs.css')
      expect(File).to exist(copied)
      expect(File.read(copied)).to eq(shipped_stylesheet)
    end
  end

  def shipped_stylesheet
    File.read(
      File.expand_path('../../../app/assets/stylesheets/auto_platform_guide/docs.css', __dir__)
    )
  end
end

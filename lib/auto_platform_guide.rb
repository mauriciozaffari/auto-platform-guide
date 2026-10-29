# frozen_string_literal: true

require 'auto_platform_guide/version'
require 'auto_platform_guide/configuration'
require 'auto_platform_guide/spec_file'
require 'auto_platform_guide/document'
require 'auto_platform_guide/localized_generation'
require 'auto_platform_guide/generator'
require 'auto_platform_guide/docs_controller_actions'

module AutoPlatformGuide
  def self.load_engine
    require 'auto_platform_guide/engine' if defined?(Rails::Engine)
  end
  private_class_method :load_engine
end

AutoPlatformGuide.send(:load_engine)

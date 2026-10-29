# frozen_string_literal: true

require 'rails/generators'

module AutoPlatformGuide
  module Generators
    # Copies the minimal docs stylesheet into the host app.
    class StylesGenerator < Rails::Generators::Base
      source_root File.expand_path('../../../..', __dir__)

      desc 'Copy the auto-platform-guide stylesheet into app/assets/stylesheets.'

      def copy_stylesheet
        copy_file 'app/assets/stylesheets/auto_platform_guide/docs.css',
                  'app/assets/stylesheets/docs.css'
      end
    end
  end
end

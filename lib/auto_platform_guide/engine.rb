# frozen_string_literal: true

require 'rails/engine'

module AutoPlatformGuide
  class Engine < ::Rails::Engine
    initializer 'auto_platform_guide.view_paths', before: :add_view_paths do |app|
      app.config.paths['app/views'].push(root.join('app', 'views'))
    end
  end
end

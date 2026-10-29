# frozen_string_literal: true

require 'rails/engine'

module AutoPlatformGuide
  class Engine < ::Rails::Engine
    initializer 'auto_platform_guide.view_paths', before: :add_view_paths do |app|
      app.config.paths['app/views'].push(root.join('app', 'views'))
    end

    rake_tasks do
      require 'auto_platform_guide/rake_tasks'
      %w[generate check readme render].each do |name|
        Rake::Task["auto_platform_guide:#{name}"].enhance(['environment'])
      end
    end
  end
end

# frozen_string_literal: true

require 'auto_platform_guide'

module AutoPlatformGuide
  # Rake task bodies. Tasks themselves are declared below; this module keeps the
  # exit-status handling testable without invoking rake.
  module RakeTasks
    module_function

    def run(argv, failure:)
      status = Generator.run(argv)
      return if status.zero?

      abort(failure)
    end
  end
end

namespace :auto_platform_guide do
  desc 'Generate guides from every documented system spec'
  task :generate, [:spec_file] do |_task, args|
    spec_files = [args[:spec_file], *args.extras].compact
    AutoPlatformGuide::RakeTasks.run(spec_files, failure: 'Guide generation failed')
  end

  desc 'Verify committed guides match their specs; fails when stale'
  task :check do
    AutoPlatformGuide::RakeTasks.run(
      ['--check'],
      failure: 'Committed guides are stale; run rake auto_platform_guide:generate'
    )
  end

  desc 'Rebuild only the README table of contents'
  task :readme do
    AutoPlatformGuide::RakeTasks.run(['--readme-only'], failure: 'README generation failed')
  end

  desc 'Re-render guides from doc comments, reusing screenshots on disk'
  task :render do
    AutoPlatformGuide::RakeTasks.run(['--render-only'], failure: 'Guide rendering failed')
  end
end

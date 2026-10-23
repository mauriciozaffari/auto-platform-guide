# frozen_string_literal: true

require 'rails_quality_assurance/all'

require 'auto_platform_guide'
require 'auto-platform-guide'

# The gemspec loads version.rb before SimpleCov starts, so its lines are not
# tracked. Reload it once coverage is running.
if defined?(AutoPlatformGuide::VERSION)
  AutoPlatformGuide.class_eval { remove_const(:VERSION) }
  $LOADED_FEATURES.delete_if { |path| path.end_with?('auto_platform_guide/version.rb') }
end
require 'auto_platform_guide/version'

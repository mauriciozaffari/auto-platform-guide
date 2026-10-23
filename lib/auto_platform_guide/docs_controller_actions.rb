# frozen_string_literal: true

module AutoPlatformGuide
  # Include into the host app's docs controller. The host keeps its own
  # controller class so authentication (before_actions, layouts) stays
  # application-owned:
  #
  #   class DocsController < AdminController
  #     include AutoPlatformGuide::DocsControllerActions
  #   end
  module DocsControllerActions
    def show
      @document = Document.find(params[:id] || 'README')
      # Markdown links end in `.md`, which Rails would otherwise read as the response format.
      render template: 'docs/show', formats: :html
    end
  end
end

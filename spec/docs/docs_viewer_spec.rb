# frozen_string_literal: true

# @category Reference
# @order 400
#
# = Docs viewer
# `AutoPlatformGuide::Document` finds a markdown file under `docs_root` and
# renders it; `DocsControllerActions` and the shipped template serve it.
#
# == Controller
#
# ```ruby
# class DocsController < AdminController
#   include AutoPlatformGuide::DocsControllerActions
# end
# ```
#
# ```ruby
# # config/routes.rb
# get '/docs(/*id)', to: 'docs#show', as: 'docs'
# ```
#
# `show` reads `params[:id]`, defaults to `README`, and renders `docs/show` as
# HTML so links ending in `.md` are not read as the response format.
#
# == Document lookup
#
# `Document.find('platform-guide/OVERVIEW')` takes a path without the `.md`
# extension. Without a name it resolves a folder index (`README` or
# `00 - Index`) and raises `Document::RecordNotFound` when nothing matches.
#
# > [!IMPORTANT]
# > The template links to `/docs`; mount the route at that path. Override
# > `app/views/docs/show.html.erb` in the host app to change the chrome.

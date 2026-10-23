<!--
Generated: 2026-10-23 02:03:38 UTC
-->

<h1 id="docs-viewer">Docs viewer</h1>

`AutoPlatformGuide::Document` finds a markdown file under `docs_root` and
renders it; `DocsControllerActions` and the shipped template serve it.


<h2 id="controller">Controller</h2>


```ruby
class DocsController < AdminController
  include AutoPlatformGuide::DocsControllerActions
end
```

```ruby
# config/routes.rb
get '/docs(/*id)', to: 'docs#show', as: 'docs'
```

`show` reads `params[:id]`, defaults to `README`, and renders `docs/show` as
HTML so links ending in `.md` are not read as the response format.


<h2 id="document-lookup">Document lookup</h2>


`Document.find('platform-guide/OVERVIEW')` takes a path without the `.md`
extension. Without a name it resolves a folder index (`README` or
`00 - Index`) and raises `Document::RecordNotFound` when nothing matches.

> [!IMPORTANT]
> Links are built from `docs_path` (default `/docs`); set it to the path you
> mount. Override `app/views/docs/show.html.erb` in the host app to change the
> chrome.

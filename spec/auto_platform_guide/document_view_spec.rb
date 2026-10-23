# frozen_string_literal: true

require 'spec_helper'
require 'action_view'

RSpec.describe AutoPlatformGuide::Document do
  describe 'the docs/show template' do
    subject(:html) do
      view = ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
      # ActionController::Base exposes this helper in a real request.
      view.define_singleton_method(:content_security_policy_nonce) { nil }
      view.assign(document:)
      view.render(template: 'docs/show')
    end

    let(:views) { File.expand_path('../../app/views', __dir__) }
    let(:lookup) { ActionView::LookupContext.new(ActionView::PathSet.new([ActionView::FileSystemResolver.new(views)])) }
    let(:document) do
      instance_double(
        described_class,
        title: 'Alpha Guide',
        breadcrumbs: [{ name: 'Platform Guide', path: '/docs/platform-guide' }],
        render: '<h1>Alpha Guide</h1>'.html_safe
      )
    end

    it 'renders the document, breadcrumbs and mermaid bootstrap with no host helpers' do
      expect(html).to include('<h1>Alpha Guide</h1>')
      expect(html).to include('href="/docs"')
      expect(html).to include('href="/docs/platform-guide"')
      expect(html).to include('window.mermaid')
    end

    it 'does not escape the rendered markdown' do
      expect(html).not_to include('&lt;h1&gt;')
    end
  end
end

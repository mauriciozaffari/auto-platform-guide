# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoPlatformGuide::DocsControllerActions do
  subject(:controller) { host_class.new }

  let(:host_class) do
    Class.new do
      include AutoPlatformGuide::DocsControllerActions

      attr_accessor :params
      attr_reader :rendered, :document

      def render(options)
        @rendered = options
      end
    end
  end
  let(:document) { instance_double(AutoPlatformGuide::Document) }

  it 'finds the requested document and renders the docs template as html' do
    controller.params = { id: 'platform-guide/SETTINGS' }
    allow(AutoPlatformGuide::Document).to receive(:find).with('platform-guide/SETTINGS').and_return(document)

    controller.show

    expect(controller.document).to eq(document)
    expect(controller.rendered).to eq(template: 'docs/show', formats: :html)
  end

  it 'defaults to the README when no id is given' do
    controller.params = {}
    allow(AutoPlatformGuide::Document).to receive(:find).with('README').and_return(document)

    controller.show

    expect(controller.document).to eq(document)
  end
end

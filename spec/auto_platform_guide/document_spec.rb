# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe AutoPlatformGuide::Document do
  subject(:document) { described_class.new(path) }

  let(:root) { Pathname.new(Dir.mktmpdir) }
  let(:rails_stub) do
    Module.new do
      class << self
        attr_accessor :root
      end
    end
  end

  before do
    stub_const('Rails', rails_stub, transfer_nested_constants: true)
    rails_stub.root = root
  end

  def configure_docs_path(value)
    original = AutoPlatformGuide.configuration.docs_path
    AutoPlatformGuide.configuration.docs_path = value
    yield
  ensure
    AutoPlatformGuide.configuration.docs_path = original
  end

  describe '.where' do
    let(:create_report_path) { root.join('docs/how-to/CREATE-REPORT.md') }
    let(:delete_report_path) { root.join('docs/how-to/DELETE-REPORT.md') }

    before do
      allow(root).to receive(:glob).and_call_original
    end

    it 'returns documents matching glob for a folder' do
      allow(root).to receive(:glob).with('docs/how-to/*.md').and_return([create_report_path, delete_report_path])
      docs = described_class.where(folder: 'how-to')
      expect(docs).to all(be_a(described_class))
      expect(docs.map(&:path)).to eq([create_report_path, delete_report_path].sort)
    end

    it 'returns documents matching a specific name anywhere' do
      allow(root).to receive(:glob).with('{docs/**/,}CREATE-REPORT.md').and_return([create_report_path])
      docs = described_class.where(name: 'CREATE-REPORT')
      expect(docs.size).to eq(1)
      expect(docs.first.path).to eq(create_report_path)
    end

    it 'lists every document in a folder when no name is given' do
      allow(root).to receive(:glob).with('docs/how-to/*.md').and_return([create_report_path])
      expect(described_class.where(folder: 'how-to').size).to eq(1)
    end
  end

  describe '.all' do
    it 'is an alias of .where' do
      expect(described_class.method(:all)).to eq(described_class.method(:where))
    end
  end

  describe '.first and .last' do
    let(:docs) { [instance_double(described_class.to_s), instance_double(described_class.to_s)] }

    before do
      allow(described_class).to receive(:where).and_return(docs)
    end

    it 'delegates .first to .where.first' do
      expect(described_class.first).to eq(docs.first)
    end

    it 'delegates .last to .where.last' do
      expect(described_class.last).to eq(docs.last)
    end
  end

  describe '.find' do
    let(:doc) { instance_double(described_class.to_s) }

    it 'finds by name' do
      allow(described_class).to receive(:where).with(name: 'CREATE-REPORT').and_return([doc])
      expect(described_class.find('CREATE-REPORT')).to eq(doc)
      expect(described_class).to have_received(:where).with(name: 'CREATE-REPORT')
    end

    it 'falls back to README in folder when name not found' do
      allow(described_class).to receive(:where).with(name: 'how-to').and_return([])
      allow(described_class).to receive(:where).with(folder: 'how-to', name: 'README').and_return([doc])
      expect(described_class.find('how-to')).to eq(doc)
      expect(described_class).to have_received(:where).with(folder: 'how-to', name: 'README')
    end

    it 'falls back to the Obsidian index (00 - Index) when the folder has no README' do
      allow(described_class).to receive(:where).with(name: 'notes').and_return([])
      allow(described_class).to receive(:where).with(folder: 'notes', name: 'README').and_return([])
      allow(described_class).to receive(:where).with(folder: 'notes', name: '00 - Index').and_return([doc])
      expect(described_class.find('notes')).to eq(doc)
    end

    it 'raises when nothing is found' do
      allow(described_class).to receive(:where).with(name: 'missing').and_return([])
      allow(described_class).to receive(:where).with(folder: 'missing', name: 'README').and_return([])
      allow(described_class).to receive(:where).with(folder: 'missing', name: '00 - Index').and_return([])
      expect { described_class.find('missing') }
        .to raise_error(described_class::RecordNotFound, "Couldn't find document missing")
    end
  end

  describe '.docs_root' do
    it 'reads the configured docs root' do
      expect(described_class.docs_root).to eq(AutoPlatformGuide.configuration.docs_root)
    end
  end

  describe '.docs_path' do
    it 'defaults to /docs' do
      expect(described_class.docs_path).to eq('/docs')
    end

    it 'strips a trailing slash from the configured path' do
      configure_docs_path('/handbook/') do
        expect(described_class.docs_path).to eq('/handbook')
      end
    end
  end

  describe '#initialize' do
    let(:path) { root.join('docs/how-to/CREATE-REPORT.md') }

    it 'sets path, name and id from the given path' do
      expect(document.path).to eq(path)
      expect(document.name).to eq('CREATE-REPORT')
      expect(document.instance_variable_get(:@id)).to eq('how-to/CREATE-REPORT')
    end

    it 'leaves id nil for paths outside the markdown tree' do
      expect(described_class.new(root.join('docs/note.txt')).instance_variable_get(:@id)).to be_nil
    end
  end

  describe '#render' do
    let(:path) { root.join('docs/how-to/CREATE-REPORT.md') }

    it 'delegates to Renderer.render with the path and the document folder as base_dir' do
      allow(AutoPlatformGuide::Document::Renderer)
        .to receive(:render).with(path, base_dir: 'how-to').and_return('<p>ok</p>')
      expect(document.render).to eq('<p>ok</p>')
      expect(AutoPlatformGuide::Document::Renderer).to have_received(:render).with(path, base_dir: 'how-to')
    end

    context 'with a top-level document' do
      let(:path) { root.join('docs/README.md') }

      it 'passes base_dir: nil' do
        allow(AutoPlatformGuide::Document::Renderer)
          .to receive(:render).with(path, base_dir: nil).and_return('<p>ok</p>')
        document.render
        expect(AutoPlatformGuide::Document::Renderer).to have_received(:render).with(path, base_dir: nil)
      end
    end
  end

  describe '#title' do
    let(:path) { root.join('docs/how-to/create-report.md') }

    it 'titleizes the file basename' do
      expect(document.title).to eq('Create Report')
    end
  end

  describe '#breadcrumbs' do
    subject(:breadcrumbs) { document.breadcrumbs }

    let(:path) { root.join('docs/how-to/CREATE-REPORT.md') }

    it 'builds name/path hashes with cumulative paths' do
      expect(breadcrumbs).to eq([
                                  { name: 'How To', path: '/docs/how-to' },
                                  { name: 'Create Report', path: '/docs/how-to/CREATE-REPORT' }
                                ])
    end

    it 'uses the configured docs path' do
      configure_docs_path('/handbook') do
        expect(breadcrumbs.last[:path]).to eq('/handbook/how-to/CREATE-REPORT')
      end
    end

    context 'with deeper nesting' do
      let(:path) { root.join('docs/guides/how-to/CREATE-REPORT.md') }

      it 'handles deeper nesting correctly' do
        expect(breadcrumbs).to eq([
                                    { name: 'Guides', path: '/docs/guides' },
                                    { name: 'How To', path: '/docs/guides/how-to' },
                                    { name: 'Create Report', path: '/docs/guides/how-to/CREATE-REPORT' }
                                  ])
      end
    end

    context 'with a top-level document' do
      let(:path) { root.join('docs/README.md') }

      it 'returns a single crumb' do
        expect(breadcrumbs).to eq([{ name: 'Readme', path: '/docs/README' }])
      end
    end
  end

  describe AutoPlatformGuide::Document::Renderer do
    subject(:renderer) { described_class.new }

    def render_markdown(markdown)
      file = Tempfile.new(['document', '.md'])
      file.write(markdown)
      file.rewind
      renderer.render(file.path)
    ensure
      file.close
      file.unlink
    end

    describe '#image' do
      it 'renders img tag with img-responsive class' do
        html = renderer.image('https://example.com/image.png', 'Image Title', 'Alt Text')
        expected = '<img src="https://example.com/image.png" alt="Alt Text" title="Image Title" ' \
                   'class="img-responsive" />'
        expect(html).to eq(expected)
      end

      it 'handles nil title' do
        html = renderer.image('https://example.com/image.png', nil, 'Alt Text')
        expect(html).to eq('<img src="https://example.com/image.png" alt="Alt Text" class="img-responsive" />')
      end
    end

    describe '#render' do
      let(:temp_file) { Tempfile.new(['test', '.md']) }
      let(:markdown_content) { "# Test\n\n![Alt Text](https://example.com/image.png \"Image Title\")" }

      before do
        temp_file.write(markdown_content)
        temp_file.rewind
      end

      after do
        temp_file.close
        temp_file.unlink
      end

      it 'renders markdown images with img-responsive class' do
        html = renderer.render(temp_file.path)
        expect(html).to include('class="img-responsive"')
        expect(html).to include('src="https://example.com/image.png"')
        expect(html).to include('alt="Alt Text"')
      end

      it 'reuses the memoized markdown engine across renders' do
        first = renderer.markdown
        renderer.render(temp_file.path)
        expect(renderer.markdown).to be(first)
      end

      it 'renders through the class interface with an optional base_dir' do
        html = described_class.render(temp_file.path, base_dir: 'notes')
        expect(html).to include('class="img-responsive"')
      end
    end

    describe '#block_code' do
      it 'renders mermaid blocks as raw text in a <pre class="mermaid">' do
        html = renderer.block_code("flowchart TD\n  A --> B", 'mermaid')
        expect(html).to eq(%(<pre class="mermaid">flowchart TD\n  A --&gt; B</pre>))
      end

      it 'highlights non-mermaid code blocks in a code-block panel' do
        html = renderer.block_code('puts 1', 'ruby')
        expect(html).to include('class="code-block"')
        expect(html).to include('language-ruby')
      end

      it 'falls back to plain text for unknown languages' do
        html = renderer.block_code('puts 1', 'not-a-language-xyz')
        expect(html).to include('class="code-block"')
        expect(html).to include('language-plaintext')
      end
    end

    describe '#block_quote' do
      it 'renders GitHub note callouts with a callout class and title' do
        html = render_markdown("> [!NOTE]\n> Useful information.")

        expect(html).to include('<blockquote class="callout callout-note">')
        expect(html).to include(
          '<p class="callout-title"><i class="fa fa-info-circle" aria-hidden="true"></i> Note</p>'
        )
        expect(html).to include('<p>Useful information.</p>')
        expect(html).not_to include('[!NOTE]')
      end

      it 'renders every supported GitHub callout type with a matching class' do
        icons = {
          'NOTE' => 'info-circle',
          'TIP' => 'lightbulb-o',
          'IMPORTANT' => 'exclamation-circle',
          'WARNING' => 'warning',
          'CAUTION' => 'ban'
        }

        icons.each do |type, icon|
          html = render_markdown("> [!#{type}]\n> Message")

          expect(html).to include(%(class="callout callout-#{type.downcase}"))
          expect(html).to include(%(class="fa fa-#{icon}"))
          expect(html).not_to include("[!#{type}]")
        end
      end

      it 'renders adjacent callouts as separate callouts' do
        html = render_markdown("> [!NOTE]\n> One.\n\n> [!TIP]\n> Two.\n")

        expect(html.scan('class="callout callout-').size).to eq(2)
        expect(html).not_to include('[!TIP]')
      end

      it 'keeps regular blockquotes unchanged' do
        # Whitespace inside the quote depends on the host's sanitizer vendor
        # (HTML5 under Rails load_defaults, HTML4 standalone): assert fragments.
        html = render_markdown('> Regular quote')

        expect(html).to include('<blockquote>')
        expect(html).to include('<p>Regular quote</p>')
        expect(html).not_to include('callout')
      end
    end

    describe 'wikilinks' do
      subject(:renderer) { described_class.new(base_dir: 'notes') }

      it 'links [[Note]] to a sibling note in the same folder' do
        expect(render_markdown('See [[Team]].'))
          .to include('<a href="/docs/notes/Team">Team</a>')
      end

      it 'uses the configured docs path' do
        configure_docs_path('/handbook') do
          expect(render_markdown('See [[Team]].'))
            .to include('<a href="/handbook/notes/Team">Team</a>')
        end
      end

      it 'url-encodes spaces in note names' do
        expect(render_markdown('See [[Location System]].'))
          .to include('href="/docs/notes/Location%20System"')
      end

      it 'links [[Note#Heading]] with a Redcarpet-compatible anchor (underscores dropped)' do
        html = render_markdown('See [[TeamSettings#assign_default_owner]].')
        expect(html).to include('href="/docs/notes/TeamSettings#assigndefaultowner"')
        expect(html).to include('TeamSettings › assign_default_owner')
      end

      it 'uses the alias as link text when provided' do
        expect(render_markdown('See [[Team|the team]].')).to include('>the team</a>')
      end

      it 'links from the docs root without a base_dir' do
        plain = described_class.new
        file = Tempfile.new(['document', '.md'])
        file.write('See [[Team]].')
        file.rewind
        expect(plain.render(file.path)).to include('<a href="/docs/Team">Team</a>')
        file.close
        file.unlink
      end

      it 'leaves wikilinks inside fenced code blocks untouched' do
        html = render_markdown("```\n[[Team]]\n```")
        expect(html).to include('[[Team]]')
        expect(html).not_to include('href="/docs/notes/Team"')
      end

      it 'leaves wikilinks inside inline code untouched' do
        html = render_markdown('Use `[[Team]]` literally.')
        expect(html).to include('[[Team]]')
        expect(html).not_to include('href="/docs/notes/Team"')
      end
    end
  end
end

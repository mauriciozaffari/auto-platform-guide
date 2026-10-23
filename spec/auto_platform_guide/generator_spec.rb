# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe AutoPlatformGuide::Generator do
  subject(:generator) { described_class.new([]) }

  let(:spec_file) { File.join(Dir.mktmpdir, 'example_spec.rb') }

  before do
    File.write(spec_file, <<~RUBY)
      # @category Settings
      # @order 200
      #
      # = Managing Settings
      # How to manage settings.
      describe 'Settings' do
      end
    RUBY
  end

  context 'with an isolated project dir' do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          config = AutoPlatformGuide.configuration
          old_values = {
            generated_docs_dir: config.generated_docs_dir,
            screenshots_dir: config.screenshots_dir,
            specs_glob: config.specs_glob,
            readme_preamble: config.readme_preamble
          }
          config.generated_docs_dir = 'guides'
          config.screenshots_dir = 'shots'
          config.specs_glob = 'spec/*_spec.rb'
          begin
            example.run
          ensure
            old_values.each { |key, value| config.public_send("#{key}=", value) }
          end
        end
      end
    end

    let(:isolated_spec) { 'spec/example_spec.rb' }

    def render_body(spec_path)
      parsed = AutoPlatformGuide::SpecFile.new(spec_path)
      generator.send(:render_doc_body, parsed.doc_comments, parsed.screenshot_calls)
    end

    before do
      FileUtils.mkdir_p('spec')
      File.write(isolated_spec, <<~RUBY)
        # = Managing Settings
        # How to manage settings.
        describe 'Settings' do
          it { doc_screenshot('settings') }

          # == Details
          # More prose here.
          it { doc_screenshot('details') }
        end
      RUBY
    end

    it 'reports stale when the output file is missing' do
      expect(described_class.new([isolated_spec]).up_to_date?).to be(false)
    end

    it 'run returns 1 in --check mode instead of exiting' do
      expect(described_class.run(['--check', isolated_spec])).to eq(1)
    end

    it 'embeds existing screenshots and skips missing files' do
      FileUtils.mkdir_p('shots')
      FileUtils.touch('shots/settings.png')
      body = render_body(isolated_spec)
      expect(body).to include('![settings](/shots/settings.png)')
      expect(body).not_to include('details.png')
    end

    it 'keeps the default /docs/screenshots prefix byte-identical' do
      AutoPlatformGuide.configuration.screenshots_dir = 'docs/screenshots'
      FileUtils.mkdir_p('docs/screenshots')
      FileUtils.touch('docs/screenshots/settings.png')
      body = render_body(isolated_spec)
      expect(body).to include('![settings](/docs/screenshots/settings.png)')
    end

    it 'reports up to date once the guide is generated without running specs' do
      described_class.run(['--render-only', isolated_spec])
      expect(described_class.new([isolated_spec]).up_to_date?).to be(true)
    end

    it 'run --check returns 0 when docs are up to date' do
      described_class.run(['--render-only', isolated_spec])
      expect(described_class.run(['--check', isolated_spec])).to eq(0)
    end

    it 'treats committed docs without a timestamp header as stale' do
      FileUtils.mkdir_p('guides')
      File.write('guides/EXAMPLE.md', "# Something else\n")
      expect(described_class.new([isolated_spec]).up_to_date?).to be(false)
    end

    it 'rebuilds only the readme with --readme-only' do
      FileUtils.mkdir_p('guides')
      expect(described_class.run(['--readme-only'])).to eq(0)
      expect(File.read('guides/README.md')).to include('<h1 id="platform-guide">Platform Guide</h1>')
    end

    it 'uses the configured readme preamble' do
      AutoPlatformGuide.configuration.readme_preamble = %(<h1 id="platform-guide">Gem Guide</h1>\n)
      FileUtils.mkdir_p('guides')
      described_class.run(['--readme-only'])
      expect(File.read('guides/README.md')).to include('Gem Guide')
    end

    it 'runs the spec file through the shell when run_specs is true' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('spec')
          # The shell-out runs this file standalone (no helpers); the doc
          # call fails but process_spec only needs the run to happen.
          File.write('spec/example_spec.rb', "# = Guide Title\n# Words.\n\ndescribe('Example') { it('smoke') {} }\n")
          generator.send(:process_spec, 'spec/example_spec.rb', run_specs: true)
          expect(File).to exist('guides/EXAMPLE.md')
        end
      end
    end

    it 'groups the readme by category in workflow order' do
      File.write('spec/second_spec.rb', <<~RUBY)
        # @category Settings
        # @order 100
        #
        # = Second Guide
        # Words.
        describe 'Second' do
        end
      RUBY
      FileUtils.mkdir_p('guides')
      FileUtils.touch('guides/SECOND.md')
      FileUtils.touch('guides/EXAMPLE.md')
      described_class.run(['--readme-only'])
      readme = File.read('guides/README.md')
      expect(readme.index('id="settings"')).to be < readme.index('id="other"')
      expect(readme).to include('[Second Guide](SECOND.md)')
      expect(readme).to include('flowchart LR')
    end
  end

  it 'run with no args reports missing specs as up to date' do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        expect(described_class.run([])).to eq(0)
      end
    end
  end
end

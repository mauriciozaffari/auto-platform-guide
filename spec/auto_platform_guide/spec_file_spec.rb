# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe AutoPlatformGuide::SpecFile do
  subject(:spec_file) { described_class.new(path) }

  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'example_spec.rb') }

  after { FileUtils.rm_rf(dir) }

  before do
    File.write(path, <<~RUBY)
      # @category Settings
      # @order 200
      #
      # = Managing Settings
      # How to manage settings.
      describe 'Settings' do
        it { doc_screenshot('settings') }
        it { doc_screenshot('details') }
      end
    RUBY
  end

  it 'reads the first category and order directives' do
    expect(spec_file.directives).to eq(category: 'Settings', order: 200)
  end

  it 'is documented when it has a top-level heading' do
    expect(spec_file).to be_documented
  end

  it 'is not documented when it has no doc comment' do
    File.write(path, "describe 'Plain' do\nend\n")
    expect(spec_file).not_to be_documented
  end

  it 'extracts the top-level doc title' do
    expect(spec_file.title).to eq('Managing Settings')
  end

  it 'falls back to the file name without a top-level heading' do
    File.write(path, "# == Only a subheading\n")
    expect(spec_file.title).to eq('Example')
  end

  it 'extracts doc comment blocks' do
    comments = spec_file.doc_comments
    expect(comments.pluck(:title)).to eq(['Managing Settings'])
    expect(comments.first[:content]).to eq(['How to manage settings.'])
  end

  it 'strips directive lines from the comment stream' do
    expect(spec_file.doc_comments.first[:content]).not_to include(a_string_matching(/@category/))
  end

  it 'records the heading line number and level' do
    comment = spec_file.doc_comments.first
    expect(comment).to include(level: 1, line_number: 4)
  end

  it 'ignores a divider comment line with no title' do
    File.write(path, "# ==== \n# = Real\n# body\n")
    expect(spec_file.doc_comments.pluck(:title, :content)).to eq([['Real', ['body']]])
  end

  it 'saves the previous section when headings are adjacent' do
    File.write(path, "# = First\n# words\n# = Second\n# more\n")
    expect(spec_file.doc_comments.pluck(:title)).to eq(%w[First Second])
  end

  it 'ends a block at the first non-comment line' do
    File.write(path, "# = First\n# words\nit { }\n# = Second\n")
    expect(spec_file.doc_comments.pluck(:title, :content)).to eq([['First', ['words']], ['Second', []]])
  end

  it 'finds screenshot calls with their line numbers' do
    expect(spec_file.screenshot_calls).to eq(
      [{ path: 'settings', line_number: 7 }, { path: 'details', line_number: 8 }]
    )
  end

  it 'ignores screenshot calls that are not literal names' do
    File.write(path, "it { doc_screenshot(variable) }\n")
    expect(spec_file.screenshot_calls).to be_empty
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe AutoPlatformGuide::TableOfContents do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        config = AutoPlatformGuide.configuration
        old_dir = config.generated_docs_dir
        config.generated_docs_dir = 'guides'
        FileUtils.mkdir_p('guides')
        begin
          example.run
        ensure
          config.generated_docs_dir = old_dir
        end
      end
    end
  end

  before { write_toc('toc.yml', 'First' => 'Alpha', 'Second' => 'Alpha', 'Third' => 'Beta') }

  def write_toc(name, categories)
    entries = categories.map { |title, category| { 'id' => title.upcase, 'title' => title, 'category' => category } }
    File.write(File.join('guides', name), entries.to_yaml)
  end

  it 'loads the entries in order' do
    expect(described_class.load.entries.map(&:id)).to eq(%w[FIRST SECOND THIRD])
  end

  it 'groups the entries by category in first-seen order' do
    groups = described_class.load.groups.transform_values { |entries| entries.map(&:id) }

    expect(groups).to eq('Alpha' => %w[FIRST SECOND], 'Beta' => %w[THIRD])
  end

  it 'returns the neighbours of a guide' do
    neighbours = described_class.load.neighbours('SECOND')

    expect([neighbours[:previous].id, neighbours[:next].id]).to eq(%w[FIRST THIRD])
  end

  it 'omits the side without a neighbour' do
    expect(described_class.load.neighbours('FIRST').keys).to eq([:next])
    expect(described_class.load.neighbours('THIRD').keys).to eq([:previous])
  end

  it 'returns no neighbours for an unknown guide' do
    expect(described_class.load.neighbours('MISSING')).to eq({})
  end

  it 'falls back to the English toc when the locale has none' do
    write_toc('toc.pt-BR.yml', 'Primeiro' => 'Alfa')

    expect(described_class.load(locale: 'pt-BR').entries.map(&:title)).to eq(['Primeiro'])
    expect(described_class.load(locale: 'es').entries.map(&:id)).to eq(%w[FIRST SECOND THIRD])
  end

  it 'writes the toc for its locale' do
    entries = [described_class::Entry.new(id: 'GUIDE', title: 'Guide', category: 'Settings')]
    described_class.new(entries, locale: 'pt-BR').write

    expect(YAML.load_file('guides/toc.pt-BR.yml')).to eq(
      [{ 'id' => 'GUIDE', 'title' => 'Guide', 'category' => 'Settings' }]
    )
  end

  it 'reports the toc stale while it is missing or differs' do
    toc = described_class.new([described_class::Entry.new(id: 'GUIDE', title: 'Guide', category: 'Settings')])

    expect(toc.stale?).to be(true)
    toc.write
    expect(toc.stale?).to be(false)

    File.write('guides/toc.yml', "--- []\n")
    expect(toc.stale?).to be(true)
  end
end

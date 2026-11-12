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

  before do
    write_toc('toc.yml', %w[First Second Third])
  end

  def write_toc(name, titles)
    entries = titles.map { |title| { 'id' => title.upcase, 'title' => title } }
    File.write(File.join('guides', name), entries.to_yaml)
  end

  def entry(title)
    described_class::Entry.new(id: title.upcase, title:)
  end

  it 'reads the ordered entries' do
    expect(described_class.new.entries).to eq([entry('First'), entry('Second'), entry('Third')])
  end

  it 'returns the neighbours of a guide' do
    expect(described_class.neighbours('SECOND')).to eq(previous: entry('First'), next: entry('Third'))
  end

  it 'omits the side without a neighbour' do
    expect(described_class.neighbours('FIRST')).to eq(next: entry('Second'))
    expect(described_class.neighbours('THIRD')).to eq(previous: entry('Second'))
  end

  it 'returns no neighbours for an unknown guide' do
    expect(described_class.neighbours('MISSING')).to eq({})
  end

  it 'prefers the localized toc and falls back to English' do
    write_toc('toc.pt-BR.yml', %w[Primeiro])

    expect(described_class.new(locale: 'pt-BR').entries).to eq([entry('Primeiro')])
    expect(described_class.new(locale: 'es').entries.first).to eq(entry('First'))
  end
end

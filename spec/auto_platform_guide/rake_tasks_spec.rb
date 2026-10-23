# frozen_string_literal: true

require 'spec_helper'
require 'rake'
require 'auto_platform_guide/rake_tasks'

RSpec.describe AutoPlatformGuide::RakeTasks do
  before do
    allow(AutoPlatformGuide::Generator).to receive(:run).and_return(0)
  end

  def invoke(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  it 'generates every documented spec' do
    invoke('auto_platform_guide:generate')

    expect(AutoPlatformGuide::Generator).to have_received(:run).with([])
  end

  it 'generates the specs given as task arguments' do
    invoke('auto_platform_guide:generate', 'spec/a_spec.rb', 'spec/b_spec.rb')

    expect(AutoPlatformGuide::Generator).to have_received(:run).with(%w[spec/a_spec.rb spec/b_spec.rb])
  end

  it 'checks whether committed guides are stale' do
    invoke('auto_platform_guide:check')

    expect(AutoPlatformGuide::Generator).to have_received(:run).with(['--check'])
  end

  it 'rebuilds the README' do
    invoke('auto_platform_guide:readme')

    expect(AutoPlatformGuide::Generator).to have_received(:run).with(['--readme-only'])
  end

  it 'renders guides without running specs' do
    invoke('auto_platform_guide:render')

    expect(AutoPlatformGuide::Generator).to have_received(:run).with(['--render-only'])
  end

  it 'exits non-zero when docs are stale' do
    allow(AutoPlatformGuide::Generator).to receive(:run).and_return(1)

    expect { invoke('auto_platform_guide:check') }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
  end
end

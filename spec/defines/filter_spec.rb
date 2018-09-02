require 'spec_helper'

describe 'duplicacy::filter' do
  # Don't declare the filter file without specifying filters
  context 'no filters' do
    let(:title) { 'my-repo_filters' }
    let(:params) do
      {
        'pref_dir' => '/my/repo/dir/',
        'user' => 'me',
      }
    end

    # Compiles with no arguments
    it { is_expected.to compile.and_raise_error(%r{At least one filter entry must be provided!}) }
  end

  # Works properly with one filter line
  context 'working filters' do
    let(:title) { 'my-repo_filters' }
    let(:params) do
      {
        'pref_dir' => '/my/repo/dir',
        'user' => 'me',
        'filter_entries' => [
          '+foo/bar/*',
          '-*',
        ],
      }
    end

    # Filter file should be created
    it { is_expected.to contain_file('/my/repo/dir/filters').with_ensure('file').with_owner('me').with_group('me').with_mode('0644') }

    # Rule lines should exist which depend on the file
    it { is_expected.to contain_file_line('rule_0').that_requires('File[/my/repo/dir/filters]') }
    it { is_expected.to contain_file_line('rule_1').that_requires(['File[/my/repo/dir/filters]', 'File_line[rule_0]']) }
  end

  # This doesn't do anything at the moment
  context 'test compilation' do
    let(:title) { 'namevar' }
    let(:params) do
      {}
    end

    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts }

        it { is_expected.to compile }
      end
    end
  end
end

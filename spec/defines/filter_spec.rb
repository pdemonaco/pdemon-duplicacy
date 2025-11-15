# frozen_string_literal: true

require 'spec_helper'

describe 'duplicacy::filter' do
  # Don't declare the filter file without specifying filters
  context 'no filters' do
    let(:title) { 'my-repo_filters' }
    let(:params) do
      {
        'pref_dir' => '/my/backup/dir/.duplicacy/',
        'user' => 'me',
      }
    end

    # Compiles with no filter arguments
    it 'fails to compile with no arguments' do
      is_expected.to compile.and_raise_error(%r{At least one filter entry must be provided!})
    end
  end

  # Works properly with one filter line
  context 'working filters' do
    let(:title) { 'my-repo_filters' }
    let(:params) do
      {
        'pref_dir' => '/my/backup/dir/.duplicacy',
        'user' => 'me',
        'rules' => [
          '+foo/bar/*',
          '-*',
        ],
      }
    end

    # Filter file should be created
    it 'creates the filter file' do
      is_expected.to contain_file('/my/backup/dir/.duplicacy/filters').with(
        ensure: 'file',
        owner: 'me',
        group: 'me',
        mode: '0644',
      )
    end

    # There should be two rules
    it 'creates two rules' do
      is_expected.to have_file_line_resource_count(2)
    end

    # Rule lines should exist which depend on the file and the previous rule
    it 'creates rule 0' do
      is_expected.to contain_file_line('rule_0').that_requires('File[/my/backup/dir/.duplicacy/filters]')
    end
    it 'creates rule 1' do
      is_expected.to contain_file_line('rule_1').that_requires(['File[/my/backup/dir/.duplicacy/filters]', 'File_line[rule_0]'])
    end
  end
end

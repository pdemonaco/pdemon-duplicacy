require 'spec_helper'

describe 'duplicacy::storage' do
  # Test malformed encryption stanza
  context 'encryption set without password' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
        'target'  => {
          'url'           => 'b2://test-storage',
          'b2_account_id' => 'this-is-my-accound-id',
          'b2_application_key' => 'this-is-my-key',
        },
        'encryption' => {
          'garbage' => 'this-should-be-password',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{Password mandatory when encryption is enabled!}) }
  end

  # Test target not specified
  context 'missing target' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$target is mandatory!}) }
  end

  # Test target url not specified
  context 'missing url' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
        'target' => {
          'garbage' => 'this should be the url',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$target is mandatory!}) }
  end

  # Test unsupported backend
  context 'unsupported backend' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
        'target' => {
          'url' => 'b3://this-isnt-a-thing',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{Unrecognized url: }) }
  end

  # Test missing b2 data
  context 'b2 missing account_id' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
        'target' => {
          'url' => 'b2://no-params',
          'b2_application_key' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_account_id is mandatory for }) }
  end

  context 'b2 missing application_key' do
    let(:title) { 'test_storage' }
    let(:params) do
      {
        'storage_name' => 'test_storage',
        'repo_id' => 'test_repo',
        'path'    => '/my/super/safe/data',
        'target' => {
          'url' => 'b2://no-params',
          'b2_account_id' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_application_key is mandatory for }) }
  end

  # Valid configuration with defaults where possible
  context 'valid using default values' do
    let(:title) { 'my-repo_default' }
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_id' => 'my-repo',
        'path'    => '/my/super/safe/data',
        'target'  => {
          'url' => 'b2://test-storage',
          'b2_account_id' => 'this-is-my-accound-id',
          'b2_application_key' => 'this-is-my-key',
        },
        'encryption' => {
          'password' => 'secret-sauce',
        },
      }
    end

    # Ensure it compiles
    it { is_expected.to compile }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo_default').with_command(%r{duplicacy init -e default b2://test-storage}) }

    # Validate the working directory
    it { is_expected.to contain_exec('init_my-repo_default').with_cwd('/my/super/safe/data') }

    # Validate the environment
    it {
      is_expected.to contain_exec('init_my-repo_default').with_environment(
        [
          'DUPLICACY_PASSWORD=secret-sauce',
          'DUPLICACY_B2_ID=this-is-my-accound-id',
          'DUPLICACY_B2_KEY=this-is-my-key',
        ],
      )
    }
  end

  # Attempt to build on each OS
  context 'test-build' do
    let(:title) { 'my-repo_default' }
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_id' => 'my-repo',
        'path'    => '/my/super/safe/data',
        'target'  => {
          'url' => 'b2://test-storage',
          'b2_account_id' => 'this-is-my-accound-id',
          'b2_application_key' => 'this-is-my-key',
        },
        'encryption' => {
          'password' => 'secret-sauce',
        },
      }
    end

    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts }

        it { is_expected.to compile }
      end
    end
  end
end

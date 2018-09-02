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
          'url' => 'b2://test-storage',
          'b2_id' => 'this-is-my-accound-id',
          'b2_app_key' => 'this-is-my-key',
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
          'b2_app_key' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_id is mandatory for }) }
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
          'b2_id' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_app_key is mandatory for }) }
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
          'b2_id' => 'this-is-my-accound-id',
          'b2_app_key' => 'this-is-my-key',
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

  # Fully specified values
  context 'valid with full specification' do
    let(:title) { 'my-repo_default' }
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_id' => 'my-repo',
        'path'    => '/my/super/safe/data',
        'target'  => {
          'url' => 'b2://test-storage',
          'b2_id' => 'this-is-my-accound-id',
          'b2_app_key' => 'this-is-my-key',
        },
        'encryption' => {
          'password' => 'secret-sauce',
          'iterations' => '32768',
        },
        'chunk_parameters' => {
          'size' => 4_194_304,
          'max' => 16_777_216,
          'min' => 1_048_576,
        },
      }
    end

    # Ensure it compiles
    it { is_expected.to compile }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo_default').with_command(%r{duplicacy init -e -iterations 32768 -c 4194304 -max 16777216 -min 1048576 default b2://test-storage}) }

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

  # Only size is specified
  context 'calculated chunk min and max values' do
    let(:title) { 'my-repo_default' }
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_id' => 'my-repo',
        'path'    => '/my/super/safe/data',
        'target'  => {
          'url' => 'b2://test-storage',
          'b2_id' => 'this-is-my-accound-id',
          'b2_app_key' => 'this-is-my-key',
        },
        'encryption' => {
          'password' => 'secret-sauce',
        },
        'chunk_parameters' => {
          'size' => 8_388_608,
        },
      }
    end

    # Ensure it compiles
    it { is_expected.to compile }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo_default').with_command(%r{duplicacy init -e -c 8388608 -max 33554432 -min 2097152 default b2://test-storage}) }

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
end

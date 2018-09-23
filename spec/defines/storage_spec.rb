require 'spec_helper'

describe 'duplicacy::storage' do
  # Test malformed encryption stanza
  context 'encryption set without password' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
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
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$target is mandatory!}) }
  end

  # Test target url not specified
  context 'missing url' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
          'garbage' => 'this should be the url',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$target is mandatory!}) }
  end

  # Test unsupported backend
  context 'unsupported backend' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
          'url' => 'b3://this-isnt-a-thing',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{Unrecognized url: }) }
  end

  # Test missing b2 data
  context 'b2 missing account_id' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
          'url' => 'b2://no-params',
          'b2_app_key' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_id is mandatory for }) }
  end

  context 'b2 missing application_key' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'test_repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
          'url' => 'b2://no-params',
          'b2_id' => 'not-enough',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{\$b2_app_key is mandatory for }) }
  end

  context 'b2 alt storage without encryption' do
    let(:title) { 'other_bucket' }
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_id' => 'my-repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
          'url' => 'b2://no-params',
          'b2_id' => 'my-id',
          'b2_app_key' => 'my-app-key',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the command
    it {
      is_expected.to contain_exec('add_my-repo_other_bucket').with(
        'command' => %r{duplicacy add other_bucket my-repo b2://no-params},
        'cwd' => '/my/super/safe/data',
        'path' => '/usr/local/bin:/usr/bin:/bin',
      )
    }

    # There should be a file
    it { is_expected.to have_file_resource_count(1) }
    it {
      is_expected.to contain_file('env_my-repo_other_bucket').with(
        'ensure' => 'file',
        'path' => '/my/super/safe/data/.duplicacy/puppet/scripts/other_bucket.env',
      )
    }
    it {
      is_expected.to contain_file('env_my-repo_other_bucket').with_content(
        [
          '#!/bin/sh
# Export B2 Parameters
export DUPLICACY_OTHER_BUCKET_B2_ID="my-id"
export DUPLICACY_OTHER_BUCKET_B2_KEY="my-app-key"
',
        ],
      )
    }
    it { is_expected.to contain_file('env_my-repo_other_bucket').with_owner('me') }
    it { is_expected.to contain_file('env_my-repo_other_bucket').with_group('me') }
    it { is_expected.to contain_file('env_my-repo_other_bucket').with_mode('0600') }

    it {
      is_expected.to contain_exec('add_my-repo_other_bucket').with_onlyif(
        [
          'test -f /my/super/safe/data/.duplicacy/preferences',
          'test 0 -eq $(sed -e \'s/"//g\' /my/super/safe/data/duplicacy/preferences | awk \'/name/ {print $2}\' | grep other_bucket | wc -l)',
        ],
      )
    }

    # Validate the environment
    it {
      is_expected.to contain_exec('add_my-repo_other_bucket').with_environment(
        [
          'DUPLICACY_OTHER_BUCKET_B2_ID="my-id"',
          'DUPLICACY_OTHER_BUCKET_B2_KEY="my-app-key"',
        ],
      )
    }
  end

  # Valid configuration with defaults where possible
  context 'valid using default values' do
    let(:title) { 'my-repo_default' }
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_id' => 'my-repo',
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
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
    it { is_expected.to compile.with_all_deps }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo').with_command(%r{duplicacy init -e my-repo b2://test-storage}) }
    it { is_expected.to contain_exec('init_my-repo').with_cwd('/my/super/safe/data') }

    # There should be a file
    it { is_expected.to have_file_resource_count(1) }
    it { is_expected.to contain_file('env_my-repo_default').with_ensure('file') }
    it { is_expected.to contain_file('env_my-repo_default').with_path('/my/super/safe/data/.duplicacy/puppet/scripts/default.env') }
    it {
      is_expected.to contain_file('env_my-repo_default').with_content(
        [
          '#!/bin/sh
# Export B2 Parameters
export DUPLICACY_B2_ID="this-is-my-accound-id"
export DUPLICACY_B2_KEY="this-is-my-key"
# Export Encryption Password
export DUPLICACY_PASSWORD="secret-sauce"
',
        ],
      )
    }

    # Validate the environment
    it {
      is_expected.to contain_exec('init_my-repo').with_environment(
        [
          'DUPLICACY_PASSWORD="secret-sauce"',
          'DUPLICACY_B2_ID="this-is-my-accound-id"',
          'DUPLICACY_B2_KEY="this-is-my-key"',
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
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
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
    it { is_expected.to compile.with_all_deps }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo').with_command(%r{duplicacy init -e -iterations 32768 -c 4194304 -max 16777216 -min 1048576 my-repo b2://test-storage}) }
    it { is_expected.to contain_exec('init_my-repo').with_cwd('/my/super/safe/data') }
    it { is_expected.to contain_exec('init_my-repo').with_path('/usr/local/bin:/usr/bin:/bin') }

    # Validate the environment
    it {
      is_expected.to contain_exec('init_my-repo').with_environment(
        [
          'DUPLICACY_PASSWORD="secret-sauce"',
          'DUPLICACY_B2_ID="this-is-my-accound-id"',
          'DUPLICACY_B2_KEY="this-is-my-key"',
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
        'repo_path' => '/my/super/safe/data',
        'user' => 'me',
        'target' => {
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
    it { is_expected.to compile.with_all_deps }

    # Validate the command
    it { is_expected.to contain_exec('init_my-repo').with_command(%r{duplicacy init -e -c 8388608 -max 33554432 -min 2097152 my-repo b2://test-storage}) }
    it { is_expected.to contain_exec('init_my-repo').with_cwd('/my/super/safe/data') }
    it { is_expected.to contain_exec('init_my-repo').with_path('/usr/local/bin:/usr/bin:/bin') }

    # Validate the environment
    it {
      is_expected.to contain_exec('init_my-repo').with_environment(
        [
          'DUPLICACY_PASSWORD="secret-sauce"',
          'DUPLICACY_B2_ID="this-is-my-accound-id"',
          'DUPLICACY_B2_KEY="this-is-my-key"',
        ],
      )
    }
  end
end

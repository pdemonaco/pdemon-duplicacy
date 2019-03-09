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
          iterations: 7000,
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{Password mandatory when encryption is enabled!}) }
  end

  # Test that unsupported characters cause an error
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
          'password' => 'secret\'-\'sauce',
        },
      }
    end

    it { is_expected.to raise_error(Puppet::PreformattedError, %r{Password includes unsupported character '}) }
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
          b2_id: 'this should be the url',
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

    log_dir = '.duplicacy/puppet/logs'
    base_command = 'duplicacy add'

    # Validate the command
    it {
      is_expected.to contain_exec('add_my-repo_other_bucket').with(
        command: %r{#{base_command} other_bucket my-repo b2://no-params > \
    #{params['repo_path']}/#{log_dir}/my-repo_init.log},
        cwd: params['repo_path'],
        path: '/usr/local/bin:/usr/bin:/bin',
        environment: [
          "DUPLICACY_OTHER_BUCKET_B2_ID=#{params['target']['b2_id']}",
          "DUPLICACY_OTHER_BUCKET_B2_KEY=#{params['target']['b2_app_key']}",
        ],
      )
    }

    # There should be a file
    it 'defines the environment' do
      is_expected.to have_file_resource_count(1)
      is_expected.to contain_file('env_my-repo_other_bucket').with(
        ensure: 'file',
        path: '/my/super/safe/data/.duplicacy/puppet/scripts/other_bucket.env',
        content: [
          '#!/bin/sh
# Export B2 Parameters
export DUPLICACY_OTHER_BUCKET_B2_ID="my-id"
export DUPLICACY_OTHER_BUCKET_B2_KEY="my-app-key"
',
        ],
        owner: 'me',
        group: 'me',
        mode: '0600',
      )
    end

    it {
      is_expected.to contain_exec('add_my-repo_other_bucket').with(
        onlyif: [
          'test -f /my/super/safe/data/.duplicacy/preferences',
          'test 0 -eq $(sed -e \'s/"//g\' "/my/super/safe/data/duplicacy/preferences" | awk \'/name/ {print $2}\' | grep "other_bucket" | wc -l)',
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

    log_dir = '.duplicacy/puppet/logs'
    base_command = 'duplicacy init -e'

    # Validate the command
    it {
      is_expected.to contain_exec('init_my-repo').with(
        command: %r{#{base_command} my-repo b2://test-storage > \
    #{params['repo_path']}/#{log_dir}/my-repo_init.log},
        cwd: params['repo_path'],
        environment: [
          "DUPLICACY_PASSWORD=#{params['encryption']['password']}",
          "DUPLICACY_B2_ID=#{params['target']['b2_id']}",
          "DUPLICACY_B2_KEY=#{params['target']['b2_app_key']}",
        ],
      )
    }

    # There should be a file
    it { is_expected.to have_file_resource_count(1) }
    it {
      is_expected.to contain_file('env_my-repo_default').with(
        ensure: 'file',
        path: '/my/super/safe/data/.duplicacy/puppet/scripts/default.env',
        content: [
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

    log_dir = '.duplicacy/puppet/logs'
    base_command = 'duplicacy init -e -iterations 32768 -c 4194304 -max 16777216 -min 1048576'

    # Validate the command
    it {
      is_expected.to contain_exec('init_my-repo').with(
        command: "#{base_command} #{params['repo_id']} b2://test-storage > \
    #{params['repo_path']}/#{log_dir}/#{params['repo_id']}_init.log",
        cwd: params['repo_path'],
        path: '/usr/local/bin:/usr/bin:/bin',
        environment: [
          "DUPLICACY_PASSWORD=#{params['encryption']['password']}",
          "DUPLICACY_B2_ID=#{params['target']['b2_id']}",
          "DUPLICACY_B2_KEY=#{params['target']['b2_app_key']}",
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

    log_dir = '.duplicacy/puppet/logs'
    base_command = 'duplicacy init -e -c 8388608 -max 33554432 -min 2097152'

    # Validate the command
    it {
      is_expected.to contain_exec('init_my-repo').with(
        command: "#{base_command} my-repo b2://test-storage > \
    #{params['repo_path']}/#{log_dir}/my-repo_init.log",
        cwd: params['repo_path'],
        path: '/usr/local/bin:/usr/bin:/bin',
        environment: [
          "DUPLICACY_PASSWORD=#{params['encryption']['password']}",
          "DUPLICACY_B2_ID=#{params['target']['b2_id']}",
          "DUPLICACY_B2_KEY=#{params['target']['b2_app_key']}",
        ],
      )
    }
  end
end

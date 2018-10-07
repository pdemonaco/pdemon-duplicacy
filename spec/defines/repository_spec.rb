require 'spec_helper'

describe 'duplicacy::repository' do
  let(:title) { 'my-repo' }

  # No storage targets specified
  context 'Missing Targets' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {},
      }
    end

    it { is_expected.to compile.and_raise_error(%r{At least one target must be specified!}) }
  end

  # No default storage specified
  context 'No Default Storage' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {
          'storage1' => {},
          'storage2' => {},
        },
      }
    end

    it { is_expected.to compile.and_raise_error(%r{A storage target named 'default' must be defined!}) }
  end

  # One valid storage
  context 'single valid storage' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {
          'default' => {
            'target' => {
              'url' => 'b2://my-bucket',
              'b2_id' => 'my-id',
              'b2_app_key' => 'my-key',
            },
            'encryption' => {
              'password' => 'batman',
            },
          },
        },
      }
    end

    it { is_expected.to compile }

    # One storage repo
    it { is_expected.to have_duplicacy__storage_resource_count(1) }
    it { is_expected.to contain_duplicacy__storage('my-repo_default').with_storage_name('default') }

    # No filters
    it { is_expected.to have_duplicacy__filter_resource_count(0) }
  end

  # One valid storage with filters
  context 'single valid storage with filters' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {
          'default' => {
            'target' => {
              'url' => 'b2://my-bucket',
              'b2_id' => 'my-id',
              'b2_app_key' => 'my-key',
            },
            'encryption' => {
              'password' => 'batman',
            },
          },
        },
        'filter_rules' => [
          '+foo/baz/*',
          '-*',
        ],
      }
    end

    it { is_expected.to compile.with_all_deps }

    # There should be 7 files: 5 directories created here, a file in the
    # storage, and a file in the filters
    it { is_expected.to have_file_resource_count(7) }

    # One directory should be the duplicacy folder
    it {
      is_expected.to contain_file('/my/backup/dir/.duplicacy').with(
        'ensure' => 'directory',
        'mode' => '0700',
        'owner' => 'root',
        'group' => 'root',
      )
    }

    # One directory should be the puppet folder
    it {
      is_expected.to contain_file('/my/backup/dir/.duplicacy/puppet').with(
        'ensure' => 'directory',
        'mode' => '0700',
        'owner' => 'root',
        'group' => 'root',
      ).that_requires('File[/my/backup/dir/.duplicacy]')
    }

    # There should also be three subfolders of puppet: scripts, logs, locks
    it { is_expected.to contain_file('/my/backup/dir/.duplicacy/puppet/scripts').that_requires('File[/my/backup/dir/.duplicacy/puppet]') }
    it { is_expected.to contain_file('/my/backup/dir/.duplicacy/puppet/logs').that_requires('File[/my/backup/dir/.duplicacy/puppet]') }
    it { is_expected.to contain_file('/my/backup/dir/.duplicacy/puppet/locks').that_requires('File[/my/backup/dir/.duplicacy/puppet]') }

    # The log directory should be cleaned up at some frequency
    it {
      is_expected.to contain_tidy('/my/backup/dir/.duplicacy/puppet/logs').with(
        'age' => '4w',
      ).that_requires('File[/my/backup/dir/.duplicacy/puppet/logs]')
    }

    # One storage repo
    it { is_expected.to have_duplicacy__storage_resource_count(1) }
    it { is_expected.to contain_duplicacy__storage('my-repo_default').with_storage_name('default') }
    it { is_expected.to contain_duplicacy__storage('my-repo_default').with_repo_path('/my/backup/dir') }
    it { is_expected.to contain_duplicacy__storage('my-repo_default').that_requires('File[/my/backup/dir/.duplicacy/puppet]') }

    # Some filters
    it { is_expected.to have_duplicacy__filter_resource_count(1) }
    it { is_expected.to contain_duplicacy__filter('my-repo_filters').with_pref_dir('/my/backup/dir/.duplicacy') }
    it { is_expected.to contain_duplicacy__filter('my-repo_filters').that_requires('Duplicacy::Storage[my-repo_default]') }
  end

  context 'two valid storages with filters' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {
          'default' => {
            'target' => {
              'url' => 'b2://my-bucket',
              'b2_id' => 'my-id',
              'b2_app_key' => 'my-key',
            },
            'encryption' => {
              'password' => 'batman',
            },
          },
          'other_bucket' => {
            'target' => {
              'url' => 'b2://my-second-bucket',
              'b2_id' => 'my-other-id',
              'b2_app_key' => 'my-second-key',
            },
          },
        },
        'filter_rules' => [
          '+foo/baz/*',
          '-*',
        ],
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Default storage repo
    it { is_expected.to have_duplicacy__storage_resource_count(2) }
    it {
      is_expected.to contain_duplicacy__storage('my-repo_default').with(
        'storage_name' => 'default',
        'repo_path' => '/my/backup/dir',
      )
    }

    # Other repo
    it {
      is_expected.to contain_duplicacy__storage('my-repo_other_bucket').with(
        'storage_name' => 'other_bucket',
        'repo_path' => '/my/backup/dir',
      )
    }

    # The second storage sholud depend on default.
    # We need to initialize before we can add additional storage
    it { is_expected.to contain_duplicacy__storage('my-repo_other_bucket').that_requires('Duplicacy::Storage[my-repo_default]') }

    # Some filters
    it { is_expected.to have_duplicacy__filter_resource_count(1) }
    it { is_expected.to contain_duplicacy__filter('my-repo_filters').with_pref_dir('/my/backup/dir/.duplicacy') }
    it { is_expected.to contain_duplicacy__filter('my-repo_filters').that_requires('Duplicacy::Storage[my-repo_default]') }
  end

  # One valid storage with a backup schedule
  context 'single valid storage with backups and prunes' do
    let(:params) do
      {
        'repo_path' => '/my/backup/dir',
        'storage_targets' => {
          'default' => {
            'target' => {
              'url' => 'b2://my-bucket',
              'b2_id' => 'my-id',
              'b2_app_key' => 'my-key',
            },
            'encryption' => {
              'password' => 'batman',
            },
          },
        },
        'filter_rules' => [
          '+foo/baz/*',
          '-*',
        ],
        'backup_schedules' => {
          'daily-0130' => {
            'storage_name' => 'default',
            'cron_entry' => {
              'hour' => '1',
              'minute' => '30',
            },
            'threads' => 8,
            'email_recipient' => 'me@example.com',
          },
        },
        'prune_schedules' => {
          'daily-0000' => {
            'storage_name' => 'default',
            'cron_entry' => {
              'hour' => '0',
              'minute' => '0',
            },
            'keep_ranges' => [
              {
                'interval' => 0,
                'min_age' => 90,
              },
              {
                'interval' => 7,
                'min_age' => 30,
              },
              {
                'interval' => 1,
                'min_age' => 7,
              },
            ],
            'threads' => 8,
            'email_recipient' => 'me@example.com',
          },
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Ensure that the schedule is created
    it {
      is_expected.to contain_duplicacy__backup('my-repo_default_backup_daily-0130').with(
        'repo_path' => '/my/backup/dir',
        'user' => 'root',
        'threads' => 8,
        'email_recipient' => 'me@example.com',
      ).that_requires('Duplicacy::Storage[my-repo_default]')

      is_expected.to contain_duplicacy__prune("#{title}_default_daily-0000").with(
        repo_path: params['repo_path'],
        user: 'root',
        threads: 8,
        email_recipient: 'me@example.com',
      )
    }
  end
end

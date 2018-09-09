require 'spec_helper'
require 'deep_merge'

describe 'duplicacy' do
  let(:facts) do
    {
      'os' => {
        'architecture' => 'amd64',
        'family' => 'Gentoo',
        'hardware' => 'x86_64',
        'name' => 'Gentoo',
        'release' => {
          'full' =>  '2.4.1',
          'major' => '2',
          'minor' => '4',
        },
      },
    }
  end

  let(:params) do
    {
      'local_repos' => ['my-repo'],
      'repos' => {
        'my-repo' => {
          'repo_path' => '/my/backup/dir',
          'user' => 'root',
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
          'backup_schedules' => [
            {
              'storage_name' => 'default',
              'cron_entry' => {
                'hour' => '1',
                'minute' => '30',
              },
              'threads' => 8,
              'email_recipient' => 'me@example.com',
            },
          ],
        },
      },
    }
  end

  context 'Compiles' do
    it { is_expected.to compile }

    it { is_expected.to contain_package('app-backup/duplicacy-bin') }
    it { is_expected.to contain_package('mail-client/mutt') }
  end

  context 'Skipping undefined repo' do
    let(:params) do
      super().merge('local_repos' => ['missing-repo'])
    end

    it { is_expected.to contain_notify('Skipping undefined repo: missing-repo') }
  end

  context 'One real repo' do
    it { is_expected.to contain_duplicacy__repository('my-repo') }
  end
end

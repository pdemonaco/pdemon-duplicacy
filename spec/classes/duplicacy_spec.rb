require 'spec_helper'
require 'deep_merge'

describe 'duplicacy' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          local_repos: ['my-repo'],
          repos: {
            'my-repo' => {
              repo_path: '/my/backup/dir',
              user: 'root',
              storage_targets: {
                'default' => {
                  target: {
                    url: 'b2://my-bucket',
                    b2_id: 'my-id',
                    b2_app_key: 'my-key',
                  },
                  encryption: {
                    password: 'batman',
                  },
                },
              },
              filter_rules: [
                '+foo/baz/*',
                '-*',
              ],
              backup_schedules: {
                'daily-0130' => {
                  storage_name: 'default',
                  cron_entry: {
                    hour: '1',
                    minute: '30',
                  },
                  threads: 8,
                  email_recipient: 'me@example.com',
                },
              },
              prune_schedules: {
                'retain-all-30d' => {
                  schedules: {
                    'daily-prune' => {
                      repo_id: 'my-repo',
                      cron_entry: {
                        hour: '0',
                        minute: '0',
                      },
                    },
                  },
                  keep_ranges: [
                    { interval: 0, min_age: 90 },
                    { interval: 7, min_age: 30 },
                    { interval: 1, min_age: 7 },
                  ],
                  threads: 8,
                  email_recipient: 'me@example.com',
                },
              },
            },
          },
        }
      end

      it 'compiles' do
        is_expected.to compile.with_all_deps
      end

      package_list = if os =~ %r{gentoo}
                       ['app-backup/duplicacy-bin', 'mail-client/mutt']
                     else
                       ['duplicacy', 'mutt']
                     end
      package_list.each do |package|
        it "installs #{package}" do
          is_expected.to contain_package(package)
        end
      end

      context 'Skipping undefined repo' do
        let(:params) do
          super().merge(local_repos: ['missing-repo'])
        end

        it { is_expected.to contain_notify('Skipping undefined repo: missing-repo') }
      end

      context 'One real repo' do
        it { is_expected.to contain_duplicacy__repository('my-repo') }
      end
    end
  end
end

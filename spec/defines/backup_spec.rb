require 'spec_helper'

describe 'duplicacy::backup' do
  let(:title) { 'my-repo_daily' }

  context 'Invaild email' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'email_recipient' => 'batman',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Invalid email address:}) }
  end

  # Missing cron
  context 'Missing cron schedule' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'email_recipient' => 'user@example.com',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{A schedule entry must be specified in cron resource format!}) }
  end

  context 'Validate simple script' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '0',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Check the cron entry
    it {
      is_expected.to contain_cron('backup-cron_my-repo_daily').with(
        'ensure' => 'present',
        'command' => '/backup/dir/.duplicacy/puppet/scripts/backup_my-repo_daily.sh',
        'user' => 'root',
        'hour' => '0',
      ).that_requires('File[backup-script_my-repo_daily]')
    }

    # Check the basic parameters of the file
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with(
        'ensure' => 'file',
        'path' => '/backup/dir/.duplicacy/puppet/scripts/backup_my-repo_daily.sh',
        'owner' => 'root',
        'group' => 'root',
        'mode' => '0700',
      )
    }

    # Check the content
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        [
          '#!/bin/sh
#==== Constants
PATH="/usr/local/bin:/usr/bin:/bin"
STORAGE_NAME="default"
BACKUP_NAME="my-repo_daily"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# Paths
REPO_DIR="/backup/dir"
PUPPET_DIR="/backup/dir/.duplicacy/puppet"
LOCK_DIR="${PUPPET_DIR}/locks"
LOG_DIR="${PUPPET_DIR}/logs"
SCRIPT_DIR="${PUPPET_DIR}/scripts"

# Config files
LOCK_FILE="${LOCK_DIR}/default.lock"
ENV_CONFIG="${SCRIPT_DIR}/${STORAGE_NAME}.env"
LOG_FILE="${LOG_DIR}/${BACKUP_NAME}_${STORAGE_NAME}_${TIMESTAMP}.log"

#==== Check for locks and aquire
acquire_backup_lock()
{
  # Abort if locked!
  if [ -e "${LOCK_FILE}" ]
  then
    echo "${STORAGE_NAME} is locked!" >&2
    exit 1
  # Otherwise capture backup name & PID
  else
    echo "${BACKUP_NAME}: $$" > "${LOCK_FILE}"
  fi
}

#==== Main Routine

# Acquire the storage lock for this repo or abort
acquire_backup_lock

# Retrieve our credentials
source "${PUPPET_DIR}/${ENV_CONFIG}"

# Move to the root of the repository
cd "${REPO_DIR}"

# Execute the backup
duplicacy -log -background backup \
  -threads 1 >"${LOG_FILE}" 2>&1

# Release the lock
rm "${LOCK_FILE}"
',
        ],
      )
    }
  end

  context 'Validate mail commands' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'email_recipient' => 'user@example.com',
        'cron_entry' => {
          'hour' => '*/6',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Check the basic parameters of the file
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with(
        'ensure' => 'file',
        'path' => '/backup/dir/.duplicacy/puppet/scripts/backup_my-repo_daily.sh',
        'owner' => 'root',
        'group' => 'root',
        'mode' => '0700',
      )
    }

    # Check for the mail block
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        %r!# Notify someone about what happened
RC="[$][?]"
MESSAGE=""
case "[$]{RC}" in
  0\)
    STATUS="Success"
    MESSAGE="See attached log"
    ;;
  1\)
    STATUS="Failure"
    MESSAGE="Interrupted by user[.] See attached log[.]"
    ;;
  2\)
    STATUS="Failure"
    MESSAGE="Malformed arguments[.] See attached log[.]"
    ;;
  3\)
    STATUS="Failure"
    MESSAGE="Invalid argument value[.] See attached log[.]"
    ;;
  100\)
    STATUS="Failure"
    MESSAGE="Runtime error in Duplicacy code[.] See attached log[.]"
    ;;
  101\)
    STATUS="Failure"
    MESSAGE="Runtime error in an external dependency[.] See attached log[.]"
    ;;
  [*]\)
    STATUS="Unknown"
    MESSAGE="Return code - [$]{RC}[.] See attached log[.]"
    ;;
esac
echo "[$]{MESSAGE}" [|] mutt -s "Duplicacy Backup [$]{BACKUP_NAME} - [$]{STATUS}" user@example[.]com -a "[$]{LOG_FILE}"$!m,
      )
    }
  end

  context 'Check hash option' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '0',
        },
        'threads' => 8,
        'hash_mode' => true,
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        %r!duplicacy -log -background backup \\\n  -hash \\\n  -threads 8 >"[$]{LOG_FILE}" 2>&1!m,
      )
    }
  end

  context 'Check limit rate option' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '0',
        },
        'threads' => 6,
        'limit_rate' => 512,
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        %r!duplicacy -log -background backup \\\n  -limit-rate 512 \\\n  -threads 6 >"[$]{LOG_FILE}" 2>&1!m,
      )
    }
  end

  context 'Check tag option' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_path' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '0',
        },
        'threads' => 4,
        'backup_tag' => 'daily-0000',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        %r!duplicacy -log -background backup \\\n  -t daily-0000 \\\n  -threads 4 >"[$]{LOG_FILE}" 2>&1!m,
      )
    }
  end

  context 'Check alternate storage name w/ all options' do
    let(:params) do
      {
        'storage_name' => 'other_bucket',
        'repo_path' => '/my/super/safe/data',
        'pref_dir' => '/my/super/safe/data/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '0',
        },
        'hash_mode' => true,
        'limit_rate' => 1024,
        'threads' => 4,
        'backup_tag' => 'daily-0000',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it {
      is_expected.to contain_file('backup-script_my-repo_daily').with_content(
        %r!duplicacy -log -background backup \\\n  -hash \\\n  -limit-rate 1024 \\\n  -storage other_bucket \\\n  -t daily-0000 \\\n  -threads 4 >"[$]{LOG_FILE}" 2>&1!m,
      )
    }
  end
end

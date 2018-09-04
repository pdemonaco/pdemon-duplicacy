require 'spec_helper'

describe 'duplicacy::backup' do
  let(:title) { 'my-repo_daily' }

  context 'Invaild email' do
    let(:params) do
      {
        'storage_name' => 'default',
        'repo_dir' => '/backup/dir',
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
        'repo_dir' => '/backup/dir',
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
        'repo_dir' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'cron_entry' => {
          'hour' => '*/6',
        }
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
        'repo_dir' => '/backup/dir',
        'pref_dir' => '/backup/dir/.duplicacy',
        'user' => 'root',
        'email_recipient' => 'user@example.com',
        'cron_entry' => {
          'hour' => '*/6',
        }
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
end

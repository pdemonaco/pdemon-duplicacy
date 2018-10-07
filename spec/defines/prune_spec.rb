require 'spec_helper'

describe 'duplicacy::prune' do
  let(:title) { 'my-repo_default_daily-0000' }

  context 'Invaild email' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        email_recipient: 'batman',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Invalid email address:}) }
  end

  # Missing cron
  context 'Missing cron schedule' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{A schedule entry must be specified in cron resource format!}) }
  end

  # Missing keep
  context 'Missing keep range' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{At least one keep range must be specified!}) }
  end

  context 'simple daily prune' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
        ],
        threads: 2,
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Check the cron entry
    it {
      is_expected.to contain_cron("prune-cron_#{title}").with(
        'ensure' => 'present',
        'command' => "#{params[:pref_dir]}/puppet/scripts/prune_#{title}.sh",
        'user' => params[:user],
        'hour' => '0',
      ).that_requires("File[prune-script_#{title}]")
    }

    # Check the basic parameters of the file
    it {
      is_expected.to contain_file("prune-script_#{title}").with(
        ensure: 'file',
        path: "#{params[:pref_dir]}/puppet/scripts/prune_#{title}.sh",
        owner: params[:user],
        group: params[:user],
        mode: '0700',
        content: [
          '#!/bin/sh
#==== Constants
PATH="/usr/local/bin:/usr/bin:/bin"
STORAGE_NAME="default"
JOB_NAME="my-repo_default_daily-0000"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# Paths
REPO_DIR="/backup/dir"
PUPPET_DIR="/backup/dir/.duplicacy/puppet"
LOCK_DIR="${PUPPET_DIR}/locks"
LOG_DIR="${PUPPET_DIR}/logs"
SCRIPT_DIR="${PUPPET_DIR}/scripts"

# Config files
LOCK_FILE="${LOCK_DIR}/${STORAGE_NAME}.lock"
ENV_FILE="${SCRIPT_DIR}/${STORAGE_NAME}.env"
LOG_FILE="${LOG_DIR}/${JOB_NAME}_${STORAGE_NAME}_${TIMESTAMP}.log"

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
    echo "${JOB_NAME}: $$" > "${LOCK_FILE}"
  fi
}

#==== Main Routine

# Acquire the storage lock for this repo or abort
acquire_backup_lock

# Retrieve our credentials
source "${ENV_FILE}"

# Move to the root of the repository
cd "${REPO_DIR}"

# Execute
duplicacy -log -background prune \
  -keep 0:30 \
  -threads 2 >"${LOG_FILE}" 2>&1

# Release the lock
rm "${LOCK_FILE}"
',
        ],
      )
    }
  end

  context 'missing keep interval' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { min_age: 30 },
        ],
        threads: 2,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{#{title}: keep range entry missing 'interval'!}) }
  end

  context 'missing keep interval' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 30 },
        ],
        threads: 2,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{#{title}: keep range entry missing 'min_age'!}) }
  end

  context 'Validate mail commands' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
        ],
        threads: 2,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Check for the mail block
    it { 
      is_expected.to contain_file("prune-script_#{title}").with_content(
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
echo "[$]{MESSAGE}" [|] mutt -s "Duplicacy Prune [$]{JOB_NAME} - [$]{STATUS}" user@example[.]com -a "[$]{LOG_FILE}"$!m
      )
    }
  end

  context 'Enable Exhaustive Mode' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
        ],
        threads: 2,
        exhaustive: true,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it 'must contain the exhastive statement' do
      content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
      expect(content).to match(%r{duplicacy -log -background prune \\\n})
      expect(content).to match(%r{\n  -keep 0:30 \\\n})
      expect(content).to match(%r{\n  -exhaustive \\\n})
      expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
    end
  end

  context 'Check the tag list option' do
    let(:params) do
      {
        storage_name: 'default',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
        ],
        backup_tags: [
          'daily',
          'hourly',
        ],
        threads: 2,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it 'must contain both provided tag options' do
      content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
      expect(content).to match(%r{duplicacy -log -background prune \\\n})
      expect(content).to match(%r{\n  -keep 0:30 \\\n})
      expect(content).to match(%r{\n  -t daily \\\n})
      expect(content).to match(%r{\n  -t hourly \\\n})
      expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
    end
  end

  context 'alternate storage name with all options' do
    let(:params) do
      {
        storage_name: 'other_bucket',
        repo_path: '/backup/dir',
        pref_dir: '/backup/dir/.duplicacy',
        user: 'root',
        cron_entry: {
          hour: '0',
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
          { interval: 7, min_age: 7 },
        ],
        backup_tags: [
          'daily',
          'hourly',
        ],
        exhaustive: true,
        threads: 2,
        email_recipient: 'user@example.com',
      }
    end

    it { is_expected.to compile.with_all_deps }

    # Validate the backup command
    it 'must contain the exhastive statement' do
      content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
      expect(content).to match(%r{\nSTORAGE_NAME="other_bucket"})
      expect(content).to match(%r{\nduplicacy -log -background prune \\\n})
      expect(content).to match(%r{\n  -keep 0:30 \\\n})
      expect(content).to match(%r{\n  -keep 7:7 \\\n})
      expect(content).to match(%r{\n  -exhaustive \\\n})
      expect(content).to match(%r{\n  -t daily \\\n})
      expect(content).to match(%r{\n  -t hourly \\\n})
      expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
    end
  end
end

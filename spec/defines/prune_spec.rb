require 'spec_helper'

describe 'duplicacy::prune' do
  let(:title) { 'my-repo_retain-all-30d' }
  let(:params) do
    {
      default_id: 'my-repo',
      repo_path: '/backup/dir',
      pref_dir: '/backup/dir/.duplicacy',
      user: 'root',
    }
  end

  # Missing cron
  context 'Missing cron schedule' do
    it { is_expected.to compile.and_raise_error(%r{At least one schedule entry must be specified!}) }
  end

  # Missing keep
  context 'Missing keep range' do
    before(:each) do
      params.merge!(
        schedules: {
          'daily-prune' => {
            repo_id: 'my-repo',
            cron_entry: {
              hour: '0',
            },
          },
        },
      )
    end

    it { is_expected.to compile.and_raise_error(%r{At least one keep range must be specified!}) }
  end

  context 'simple daily prune' do
    before(:each) do
      params.merge!(
        schedules: {
          'daily-prune' => {
            repo_id: 'my-repo',
            cron_entry: {
              hour: '0',
            },
          },
        },
        keep_ranges: [
          { interval: 0, min_age: 30 },
        ],
        threads: 2,
      )
    end

    it 'compiles' do
      is_expected.to compile.with_all_deps
    end

    it 'creates a cron entry for each schedule' do
      params[:schedules].each do |schedule_name, schedule|
        repo_id = schedule[:repo_id]
        is_expected.to contain_cron("prune-cron_#{title}_#{schedule_name}").with(
          'ensure' => 'present',
          'command' => "#{params[:pref_dir]}/puppet/scripts/prune_#{title}.sh -i #{repo_id} -s default",
          'user' => params[:user],
          'hour' => '0',
        ).that_requires("File[prune-script_#{title}]")
      end
    end

    it 'prune script contains the correct parameters' do
      is_expected.to contain_file("prune-script_#{title}").with(
        ensure: 'file',
        path: "#{params[:pref_dir]}/puppet/scripts/prune_#{title}.sh",
        owner: params[:user],
        group: params[:user],
        mode: '0700',
        content: [
          '#!/bin/bash
#==== Constants
PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# Paths
REPO_DIR="/backup/dir"
PUPPET_DIR="/backup/dir/.duplicacy/puppet"
LOCK_DIR="${PUPPET_DIR}/locks"
LOG_DIR="${PUPPET_DIR}/logs"
SCRIPT_DIR="${PUPPET_DIR}/scripts"

#==== Print Error Message
function echoerr()
{
    printf "%s\n" "$*" >&2;
    exit 1
}

#==== Check for locks and aquire
function acquire_backup_lock()
{
  # Abort if locked!
  if [ -e "${LOCK_FILE}" ]
  then
    echoerr "${0}: ${STORAGE_NAME} is locked!"
  # Otherwise capture backup name & PID
  else
    echo "${JOB_NAME}: $$" > "${LOCK_FILE}"
  fi
}

#==== Parse Arguments
function parse_arguments()
{
  while (( "$#" ));
  do
    case "$1" in
      -i|--id)
        REPO_ID=$2
        shift 2
        ;;
      -s|--storage)
        STORAGE_NAME=$2
        shift 2
        ;;
      -*)
        echoerr "${0}: Unsupported flag ${1}"
        ;;
    esac
  done

  if [ -z "${STORAGE_NAME}" ];
  then
    echoerr "${0}: STORAGE_NAME is mandatory!"
  fi

  if [ -z "${REPO_ID}" ];
  then
    echoerr "${0}: REPO_ID is mandatory!"
  fi

  JOB_NAME="${REPO_ID}_${STORAGE_NAME}_prune"
  LOCK_FILE="${LOCK_DIR}/${STORAGE_NAME}.lock"
  LOG_FILE="${LOG_DIR}/${JOB_NAME}_${TIMESTAMP}.log"
}

#==== Main Routine

# Record the parameters
# shellcheck disable=SC2068
parse_arguments $@

# Acquire the storage lock for this repo or abort
acquire_backup_lock

# Retrieve our credentials
. "/backup/dir/.duplicacy/puppet/scripts/${STORAGE_NAME}.env"

# Move to the root of the repository
cd "${REPO_DIR}" || exit 1

# Execute
duplicacy -log -background prune \
  -id "${REPO_ID}" \
  -storage "${STORAGE_NAME}" \
  -keep 0:30 \
  -threads 2 >"${LOG_FILE}" 2>&1

# Release the lock
rm "${LOCK_FILE}"
',
        ],
      )
    end

    context 'Validate mail commands' do
      before(:each) do
        params.merge!(
          email_recipient: 'user@example.com',
        )
      end

      it { is_expected.to compile.with_all_deps }

      # Check for the mail block
      it 'adds the mail block' do
        is_expected.to contain_file("prune-script_#{title}").with_content(
          %r!# Notify someone about what happened
LOG_PARSER="[$]{SCRIPT_DIR}/log_summary.sh"
RC="[$][?]"
MESSAGE=""
case "[$]{RC}" in
  0\)
    STATUS="Success"
    MESSAGE=\$\("\${LOG_PARSER}" PRUNE "\${LOG_FILE}"\)
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
echo "[$]{MESSAGE}" [|] mutt -s "Duplicacy [$]{JOB_NAME} - [$]{STATUS}" user@example[.]com -a "[$]{LOG_FILE}"$!m,
        )
      end
    end

    context 'Enable Exhaustive Mode' do
      before(:each) do
        params.merge!(
          exhaustive: true,
        )
      end

      it { is_expected.to compile.with_all_deps }

      # Validate the backup command
      it 'must contain the exhaustive statement' do
        content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
        expect(content).to match(%r{duplicacy -log -background prune \\\n})
        expect(content).to match(%r!\n  -id "[$]{REPO_ID}" \\\n!)
        expect(content).to match(%r!\n  -storage "[$]{STORAGE_NAME}" \\\n!)
        expect(content).to match(%r{\n  -keep 0:30 \\\n})
        expect(content).to match(%r{\n  -exhaustive \\\n})
        expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
      end
    end

    context 'Check the tag list option' do
      before(:each) do
        params.merge!(
          backup_tags: [
            'daily',
            'hourly',
          ],
        )
      end

      it { is_expected.to compile.with_all_deps }

      it 'must contain both provided tag options' do
        content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
        expect(content).to match(%r{duplicacy -log -background prune \\\n})
        expect(content).to match(%r!\n  -id "[$]{REPO_ID}" \\\n!)
        expect(content).to match(%r!\n  -storage "[$]{STORAGE_NAME}" \\\n!)
        expect(content).to match(%r{\n  -keep 0:30 \\\n})
        expect(content).to match(%r{\n  -t daily \\\n})
        expect(content).to match(%r{\n  -t hourly \\\n})
        expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
      end
    end

    context 'alternate storage name with all options' do
      before(:each) do
        params.merge!(
          schedules: {
            'daily-prune' => {
              repo_id: 'my-repo',
              storage_name: 'default',
              cron_entry: {
                hour: '0',
              },
            },
            'daily-prune-other' => {
              repo_id: 'my-repo',
              storage_name: 'other_bucket',
              cron_entry: {
                hour: '0',
              },
            },
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
          email_recipient: 'user@example.com',
        )
      end

      it { is_expected.to compile.with_all_deps }

      it 'backup command contains all desired options' do
        content = catalogue.resource('file', "prune-script_#{title}").send(:parameters)[:content]
        expect(content).to match(%r{\nduplicacy -log -background prune \\\n})
        expect(content).to match(%r!\n  -id "[$]{REPO_ID}" \\\n!)
        expect(content).to match(%r!\n  -storage "[$]{STORAGE_NAME}" \\\n!)
        expect(content).to match(%r{\n  -keep 0:30 \\\n})
        expect(content).to match(%r{\n  -keep 7:7 \\\n})
        expect(content).to match(%r{\n  -exhaustive \\\n})
        expect(content).to match(%r{\n  -t daily \\\n})
        expect(content).to match(%r{\n  -t hourly \\\n})
        expect(content).to match(%r!\n  -threads 2 >"[$]{LOG_FILE}" 2>&1!)
      end

      it 'creates a cron entry for each schedule' do
        params[:schedules].each do |schedule_name, schedule|
          repo_id = schedule[:repo_id]
          storage_name = schedule[:storage_name]
          is_expected.to contain_cron("prune-cron_#{title}_#{schedule_name}").with(
            'ensure' => 'present',
            'command' => "#{params[:pref_dir]}/puppet/scripts/prune_#{title}.sh -i #{repo_id} -s #{storage_name}",
            'user' => params[:user],
            'hour' => '0',
          ).that_requires("File[prune-script_#{title}]")
        end
      end
    end
  end
end

# This define handles the creation of a single backup schedule for the target
# repository / storage combination. The schedule is carried out via a cron
# object and a script which is stored in the $pref_dir/puppet/scripts/
#
# @summary Generates a script & schedules it given the specified parameters
#
# @example Full configuration for a given job type.
#   duplicacy::prune { 'my-repo_weekly': 
#     storage_name       => 'default',
#     repo_path          => '/backup/dir',
#     pref_dir           => '/backup/dir/.duplicacy',
#     user               => 'root',
#     schedules          => {
#       'sunday-midnight' => {
#         repo_id    => 'my-repo'
#         cron_entry      => {
#           hour          => '0',
#           weekday       => '0',
#         },
#       },
#       'saturday-midnight-other-repo' => {
#         repo_id    => 'my-repo'
#         cron_entry      => {
#           hour          => '0',
#           weekday       => '6',
#         },
#       },
#     },
#     keep_ranges     => [
#       { interval => 0, min_age => 365 },
#       { interval => 30, min_age => 180 },
#       { interval => 7, min_age => 30 },
#       { interval => 1, min_age => 7 },
#     ],
#     backup_tags     => [
#       'daily',
#       'weekly',
#       'test',
#     ],
#     threads         => 4,
#     email_recipient => 'me@example.com',
#   }
#
# @example Minimal configuration
#   duplicacy::backup { 'my-repo_minimal':
#     storage_name => 'default',
#     repo_path    => '/backup/dir',
#     pref_dir     => '/backup/dir/.duplicacy',
#     user         => 'root',
#     keep_ranges  => [
#       { interval => 0, min_age => 90 },
#     schedules => {
#       'daily-midnight' => {
#         repo_id    => 'my-repo'
#         cron_entry => {
#           hour => '0',
#         },
#       },
#     },
#   }
#
# @param repo_path
#   Directory in which this particular repository resides on this machine. 
#
# @param user
#   User to whom this repository belongs.
#
# @param pref_dir
#   Directory containing the duplicacy preferences for this repository.
#   Typically this is `${repo_path}/.duplicacy` however the application can
#   support alternate paths.
#
# @param schedules
#   Each entry in this parameter has two mandatory components:
#   * `repo_id` - ID of the snapshot to be pruned. Note that this can be any
#     repository which uses the same storage backend and credentials.
#   * `cron_entry` - argument to the cron resource type, however,
#    several parameters are overridden directly. In particular, *user* and
#    *command* cannot be specified via remote arguments. For more detail see the
#    (https://puppet.com/docs/puppet/5.5/types/cron.html).
#
#   Additionally, the following optional parameter can be included 
#   * `storage_name` - Name of this particular storage backend as 
#     referenced by duplicacy for this specific repository. Note that the 
#     backend named 'default' is the primary.
# 
# @param backup_tags
#   Limit the prune to impact only backups matching the specified tag or tags.
#
# @param keep_ranges
#   An ordered list of hashes where each hash contains two values:
#   * `interval` - 1 snapshot will be kept for each interval of this length in days
#   * `min_age` - policy applies to snapshots at least this number of days old
#
#   These **must** be sorted by their M values in decreasing order - the module
#   doesn't do this for you at the moment!
#
# @param exhaustive
#   If this is enabled prune will remove unreferenced chunks created by other
#   scenarios as well as files which don't appear to be backup chunks.
#
# @param threads
#   Number of parallel execution threads which will be spawned for this backup.
#   Note that this defaults to 1 and should not be greater than the number of
#   available threads on the target machine.
#
# @param email_recipient
#   If specified, the job log will be sent to the specified address.
#
# @param default_id
#   This is the name of the current repository. It is used if repo_id is left
#   out of a given prune schedule entry.
#
#   @note This assumes email is configured and working on this system.
define duplicacy::prune (
  String[1] $repo_path,
  String[1] $default_id,
  String[1] $user,
  Hash[String, Duplicacy::PruneScheduleEntry] $schedules = {},
  Boolean $exhaustive                                    = false,
  String $pref_dir                                       = "${repo_path}/.duplicacy",
  Array[Duplicacy::KeepRange] $keep_ranges               = [],
  Optional[Array[String]] $backup_tags                   = [],
  Optional[Integer] $threads                             = 1,
  Optional[Duplicacy::EmailRecipient] $email_recipient   = undef,
) {
  # Ensure that a cron schedule was actually provided
  if empty($schedules) {
    fail('At least one schedule entry must be specified!')
  }

  # Ensure that some number of keep stanzas were specified!
  if empty($keep_ranges) {
    fail('At least one keep range must be specified!')
  }

  # Arguments for the script file
  $epp_arguments = {
    'repo_dir'        => $repo_path,
    'pref_dir'        => $pref_dir,
    'exhaustive'      => $exhaustive,
    'keep_ranges'     => $keep_ranges,
    'threads'         => $threads,
    'backup_tags'     => $backup_tags,
    'email_recipient' => $email_recipient,
  }

  # Prune Script
  $script_file = "${pref_dir}/puppet/scripts/prune_${name}.sh"

  # Generate the script file
  file { "prune-script_${name}":
    ensure  => file,
    path    => $script_file,
    owner   => $user,
    group   => $user,
    mode    => '0700',
    content => epp('duplicacy/prune.sh.epp', $epp_arguments ),
  }

  # Schedule the corresponding jobs
  $schedules.each |$schedule_name, $schedule| {
    unless('cron_entry' in $schedule) {
      fail("Schedule ${schedule_name} missing cron entry!")
    }
    if 'repo_id' in $schedule {
      $repo_id = $schedule['repo_id']
    } else {
      $repo_id = $default_id
    }
    if 'storage_name' in $schedule {
      $storage_name = $schedule['storage_name']
    } else {
      $storage_name = 'default'
    }
    $cron_entry = $schedule['cron_entry']

    cron { "prune-cron_${name}_${schedule_name}":
      ensure  => present,
      command => "${script_file} -i ${repo_id} -s ${storage_name}",
      user    => $user,
      require => File["prune-script_${name}"],
      *       => $cron_entry,
    }
  }
}

# This define handles the creation of a single backup schedule for the target
# repository / storage combination. The schedule is carried out via a cron
# object and a script which is stored in the $pref_dir/puppet/scripts/
#
# @summary Generates a script & schedules it given the specified parameters
#
# @example Full configuration for a given backup job.
#   duplicacy::prune { 'my-repo_weekly': 
#     storage_name => 'default',
#     repo_path    => '/backup/dir',
#     pref_dir     => '/backup/dir/.duplicacy',
#     user         => 'root',
#     cron_entry   => {
#       hour       => '0',
#       weekday    => '0',
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
#     cron_entry   => {
#       hour       => '0',
#     },
#   }
#
# @param storage_name [String]
#   Name of this particular storage backend as referenced by duplicacy for this
#   specific repository. Note that the backend named 'default' is the primary.
#
# @param repo_path [String]
#   Directory in which this particular repository resides on this machine. 
#
# @param user [String]
#   User to whom this repository belongs.
#
# @param pref_dir [Optional[String]]
#   Directory containing the duplicacy preferences for this repository.
#   Typically this is `${repo_path}/.duplicacy` however the application can
#   support alternate paths.
#
# @param cron_entry [Hash[String, Variant[String, Integer]]]
#   This parameter is used as an argument to the cron resource type, however,
#   several parameters are overridden directly. In particular, `user` and
#   `command` cannot be specified via remote arguments. For more detail see the
#   [puppet cron resource documentation](https://puppet.com/docs/puppet/5.5/types/cron.html).
# 
# @param backup_tags [Optional[Array[String]]]
#   Limit the prune to impact only backups matching the specified tag or tags.
#
# @param keep_ranges [Optional[Array[String]]]
#   An ordered list of hashes where each hash contains two values:
#   * `interval` - 1 snapshot will be kept for each interval of this length in days
#   * `min_age` - policy applies to snapshots at least this number of days old
#
#   These **must** be sorted by their M values in decreasing order - the module
#   doesn't do this for you at the moment!
#
# @param exhaustive [Boolean]
#   If this is enabled prune will remove unreferenced chunks created by other
#   scenarios as well as files which don't appear to be backup chunks.
#
# @param threads [Optional[Integer]]
#   Number of parallel execution threads which will be spawned for this backup.
#   Note that this defaults to 1 and should not be greater than the number of
#   available threads on the target machine.
#
# @param email_recipient [Optional[String]]
#   If specified, the job log will be sent to the specified address.
#
#   @note This assumes email is configured and working on this system.
define duplicacy::prune (
  String $storage_name                               = undef,
  String $repo_path                                  = undef,
  String $user                                       = undef,
  Hash[String, Variant[String, Integer]] $cron_entry = {},
  Boolean $exhaustive                                = false,
  String $pref_dir                                   = "${repo_path}/.duplicacy",
  Array[Hash[String, Integer]] $keep_ranges          = [],
  Optional[Array[String]] $backup_tags               = [],
  Optional[Integer] $threads                         = 1,
  Optional[String] $email_recipient                  = undef,
) {

  # Check if the mail recipient is valid
  if $email_recipient and $email_recipient !~ /[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alnum:]]{2,}/ {
    fail("Invalid email address: ${email_recipient}")
  }

  # Ensure that a cron schedule was actually provided
  if empty($cron_entry) {
    fail('A schedule entry must be specified in cron resource format!')
  }

  # Ensure that some number of keep stanzas were specified!
  if empty($keep_ranges) {
    fail('At least one keep range must be specified!')
  }

  # Arguments for the script file
  $epp_arguments = {
    'storage_name'    => $storage_name,
    'job_name'        => $name,
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

  # Add a cron entry for this user
  cron { "prune-cron_${name}":
    ensure  => present,
    command => $script_file,
    user    => $user,
    require => File["prune-script_${name}"],
    *       => $cron_entry,
  }
}

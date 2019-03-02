# This define handles the creation of a single backup schedule for the target
# repository / storage combination. The schedule is carried out via a cron
# object and a script which is stored in the $pref_dir/puppet/scripts/
#
# @summary Generates a script & schedules it given the specified parameters
#
# @example Full configuration for a given backup job.
#   duplicacy::backup { 'my-repo_daily': 
#     storage_name => 'default',
#     repo_path    => '/backup/dir',
#     pref_dir     => '/backup/dir/.duplicacy',
#     user         => 'root',
#     cron_entry   => {
#       hour       => '1',
#     },
#     backup_tag      => 'daily',
#     threads         => 4,
#     hash_mode       => true,
#     email_recipient => 'me@example.com',
#   }
#
# @example Minimal configuration
#   duplicacy::backup { 'my-repo_minimal':
#     storage_name => 'default',
#     repo_path    => '/backup/dir',
#     pref_dir     => '/backup/dir/.duplicacy',
#     user         => 'root',
#     cron_entry   => {
#       hour       => '*/6',
#     },
#   }
#
# @param storage_name
#   Name of this particular storage backend as referenced by duplicacy for this
#   specific repository. Note that the backend named 'default' is the primary.
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
# @param cron_entry
#   This parameter is used as an argument to the cron resource type, however,
#   several parameters are overridden directly. In particular, `user` and
#   `command` cannot be specified via remote arguments. For more detail see the
#  (https://puppet.com/docs/puppet/5.5/types/cron.html).
# 
# @param backup_tag
#   This string will be set as the tag argument for each backup performed by
#   this job. These can be used by various duplicacy commands to filter to
#   specific snapshots.
#
# @param threads
#   Number of parallel execution threads which will be spawned for this backup.
#   Note that this defaults to 1 and should not be greater than the number of
#   available threads on the target machine.
#
# @param hash_mode
#   Indicates whether a hash should be generated for each file to determine
#   whether a change has occured. The alternate approach simply uses file size
#   and modification timestamp. Note that this defaults to `false`.
#
# @param limit_rate
#   Maximum upload data rate in kilobytes per second (KB/s). Note that leaving
#   this unset implies no limit.
#
# @param email_recipient
#   If specified, the job log will be sent to the specified address.
#
#   @note This assumes email is configured and working on this system.
define duplicacy::backup (
  String[1] $storage_name,
  String[1] $repo_path,
  String[1] $user,
  Hash[String, Variant[String, Integer, Array]] $cron_entry = {},
  Optional[String] $pref_dir                                = "${repo_path}/.duplicacy",
  Optional[String] $backup_tag                              = undef,
  Optional[Integer] $threads                                = 1,
  Optional[Boolean] $hash_mode                              = false,
  Optional[Integer] $limit_rate                             = undef,
  Optional[String] $email_recipient                         = undef,
) {

  # Check if the mail recipient is valid
  if $email_recipient and $email_recipient !~ /[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alnum:]]{2,}/ {
    fail("Invalid email address: ${email_recipient}")
  }

  # Ensure that a cron schedule was actually provided
  if empty($cron_entry) {
    fail('A schedule entry must be specified in cron resource format!')
  }

  # Arguments for the script file
  $epp_arguments = {
    'storage_name'    => $storage_name,
    'backup_name'     => $name,
    'repo_dir'        => $repo_path,
    'pref_dir'        => $pref_dir,
    'threads'         => $threads,
    'hash_mode'       => $hash_mode,
    'limit_rate'      => $limit_rate,
    'backup_tag'      => $backup_tag,
    'email_recipient' => $email_recipient,
  }

  # Generate the script file
  file { "backup-script_${name}":
    ensure  => file,
    path    => "${pref_dir}/puppet/scripts/backup_${name}.sh",
    owner   => $user,
    group   => $user,
    mode    => '0700',
    content => epp('duplicacy/backup.sh.epp', $epp_arguments ),
  }

  # Add a cron entry for this user
  cron { "backup-cron_${name}":
    ensure  => present,
    command => "${pref_dir}/puppet/scripts/backup_${name}.sh",
    user    => $user,
    require => File["backup-script_${name}"],
    *       => $cron_entry,
  }
}

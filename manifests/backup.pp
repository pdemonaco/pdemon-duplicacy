# This define handles the creation of a single backup schedule for the target
# repository / storage combination. The schedule is carried out via a cron
# object and a script which is stored in the $pref_dir/puppet/scripts/
#
# @summary Generates a script & schedules it given the specified parameters
#
# @example Minimal Configuration
#   duplicacy::backup { 'my-repo_daily': 
#     storage_name => 'default',
#     repo_dir    => '/backup/dir',
#   }
#
# @example
# 
define duplicacy::backup(
  String $storage_name = undef,
  String $repo_dir = undef,
  String $pref_dir = undef,
  String $user = undef,
  Hash[String, Variant[String, Integer]] $cron_entry = {},
  Optional[String] $backup_tag = undef,
  Optional[Integer] $threads = 1,
  Optional[Boolean] $hash_mode = false,
  Optional[Integer] $limit_rate = undef,
  Optional[String] $email_recipient = undef,
) {

  # Check if the mail recipient is valid
  if $email_recipient and $email_recipient !~ /[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alnum:]]{2,}/ {
    fail("Invalid email address: ${email_recipient}")
  }

  # Ensure that a cron schedule was actually provided
  if empty($cron_entry) {
    fail('A schedule entry must be specified in cron resource format!')
  }

  # EPP Arguments
  $epp_arguments = {
    'storage_name'    => $storage_name,
    'backup_name'     => $name,
    'repo_dir'        => $repo_dir,
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

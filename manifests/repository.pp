# Each entity of this type corresponds to a distinct repository for duplicacy to
# back up. These repositories can potentially share backing storage resources.
# Additionally, a repository can be declared simply for pruning purposes.
#
# @summary A short summary of the purpose of this defined type.
#
# @example Fully configured repository
#   duplicacy::repository { 'my-repo':
#     repo_path        => '/path/to/the/directory',
#     user             => 'me',
#     storage_targets  => {
#       'default'    => {
#         target       => {
#           url        => 'b2://backups-and-stuff',
#           b2_id      => 'my-id',
#           b2_app_key => 'my-key',
#         },
#         encryption   => {
#           password   => 'secret-sauce',
#           iterations => 32768,
#         },
#         chunk_parameters => {
#           size           => 8388608,
#           max            => 33554432,
#           min            => 2097152,
#       },
#     },
#     backup_schedules => {
#       tri-weekly-0700 => {
#         storage_name => default,
#         cron_entry   => {
#           hour       => '7',
#           minute     => '0',
#           weekday    => ['1', '2', '6']
#         },
#         threads         => 6,
#         hash_mode       => true,
#         email_recipient => 'batman@batcave.com',
#       },
#     },
#     prune_schedules  => {
#       daily-0000     => {
#         storage_name => default,
#         cron_entry   => {
#           hour       => '0',
#         },
#         keep_ranges     => {
#           { 
#             interval => 0,
#             max_age  => 90,
#           },
#           { 
#             interval => 7,
#             max_age  => 30,
#           },
#           { 
#             interval => 1,
#             max_age  => 7,
#           },
#         },
#         threads         => 6,
#         email_recipient => 'batman@batcave.com',
#       },
#     },
#     log_retention   => '5d'
#   }
#
# @param repo_id
#   The name of this particular repository. This is a namevar.
#
# @param repo_path
#   Absolute path to the directory to be backed up. Note that backup directories
#   should not be nested. 
#
# @param user
#   The name of the user who owns this repository for a given server. This user
#   will also run the cron jobs for that system. Defaults to 'root'.
# 
# @param storage_targets
#   A hash of duplicacy::storage types against which this repo should be
#   initialized. Note that there must be an entry named 'default'. Note that
#   several of the parameters which can be directly specified to the storage
#   subtype must be omitted here. Specifically, `repo_id`, `repo_path`, and 
#   `user` as these are all overridden.
#
# @param backup_schedules Optional[Hash[String, Hash[String, Variant[String, Integer, Hash[String, Variant[String, Integer]]]]]]
#   A list of parameters and schedules for the execution of a series of backups
#   of this repository. If no schedules are provided this machine will not
#   backup this repository.
#
#   @note The following parameters must not be specified: `user`, `repo_path`
#
# @param prune_schedules 
#   A list of parameters and schedules for the execution of a series of prunes
#   of this repository. If no schedules are provided this machine will not
#   prune this repository.
#
#   @note The following parameters must not be specified: `user`, `repo_path`
#
# @param filter_rules
#   An ordered list of valid include/exclude filters for duplicacy.
#
# @param log_retention
#   The amount of time to retain logs in the log directory. Note that this is
#   simply the age parameter to a
#   [tidy](https://puppet.com/docs/puppet/5.5/types/tidy.html#tidy-attribute-age)
#   resource.
define duplicacy::repository (
  String[1] $repo_path,
  String[1] $repo_id                                                  = $name,
  String[1] $user                                                     = 'root',
  Hash[String, Duplicacy::StorageTarget] $storage_targets             = {},
  Optional[Hash[String, Duplicacy::BackupSchedule]] $backup_schedules = {},
  Optional[Hash[String, Duplicacy::PruneSchedule]] $prune_schedules   = {},
  Optional[Array[String]] $filter_rules                               = [],
  Optional[String] $log_retention                                     = '4w',
) {
  # TODO - actually really support alternate pref_dirs
  $pref_dir = "${repo_path}/.duplicacy"

  # Ensure storage configuration is valid
  if empty($storage_targets) {
    fail('At least one target must be specified!')
  } elsif !( 'default' in $storage_targets ) {
    fail('A storage target named \'default\' must be defined!')
  }

  # Create the duplicacy and puppet directories
  file { $pref_dir:
    ensure => directory,
    mode   => '0700',
    owner  => $user,
    group  => $user,
  }
  file { "${pref_dir}/puppet":
    ensure  => directory,
    mode    => '0700',
    owner   => $user,
    group   => $user,
    require => File[$pref_dir],
  }

  # Create Subdirectories
  file { default:
    ensure  => directory,
    mode    => '0700',
    owner   => $user,
    group   => $user,
    require => File["${pref_dir}/puppet"],
    ;
    "${pref_dir}/puppet/logs":
    ;
    "${pref_dir}/puppet/locks":
    ;
    "${pref_dir}/puppet/scripts":
    ;
  }

  # Create the log parsing script
  file { "${pref_dir}/puppet/scripts/log_summary.sh":
    ensure         => file,
    mode           => '0700',
    owner          => $user,
    group          => $user,
    checksum       => 'sha256',
    checksum_value => 'd419e6cacd0e6d570a2635364834d3de32981e8998e554bf1651a05393d0f00d',
    content        => file('duplicacy/log_summary.sh'),
    require        => File["${pref_dir}/puppet/scripts"],
  }

  # Initialize the default storage
  $default_params = $storage_targets['default']
  duplicacy::storage { "${repo_id}_default":
    storage_name => 'default',
    repo_id      => $repo_id,
    repo_path    => $repo_path,
    user         => $user,
    require      => File["${pref_dir}/puppet"],
    *            => $default_params,
  }

  # Initialize all of the other storage targets
  $storage_targets.each | $target, $params | {
    if $target != 'default' {
      duplicacy::storage { "${repo_id}_${target}":
        storage_name => $target,
        repo_id      => $repo_id,
        repo_path    => $repo_path,
        user         => $user,
        require      => [
          Duplicacy::Storage["${repo_id}_default"],
          File["${pref_dir}/puppet"],
        ],
        *            => $params,
      }
    }
  }

  # Configure filters
  unless empty($filter_rules) {
    duplicacy::filter { "${repo_id}_filters":
      pref_dir => $pref_dir,
      user     => $user,
      rules    => $filter_rules,
      require  => [
        Duplicacy::Storage["${repo_id}_default"],
      ],
    }
  }

  # Tidy any logs created by the jobs running on this system.
  tidy { "${pref_dir}/puppet/logs":
    age     => $log_retention,
    require => File["${pref_dir}/puppet/logs"],
  }

  # Schedule Backups
  unless(empty($backup_schedules)) {
    $backup_schedules.each | $title, $schedule | {
      $storage_name = $schedule['storage_name']
      duplicacy::backup { "${repo_id}_${storage_name}_${title}":
        repo_path => $repo_path,
        user      => $user,
        *         => $schedule,
        require   => Duplicacy::Storage["${repo_id}_${storage_name}"],
      }
    }
  }

  # Schedule Prunes
  unless(empty($prune_schedules)) {
    $prune_schedules.each | $title, $schedule | {
      $storage_name = $schedule['storage_name']
      duplicacy::prune { "${repo_id}_${storage_name}_${title}":
        repo_path => $repo_path,
        user      => $user,
        *         => $schedule,
        require   => Duplicacy::Storage["${repo_id}_${storage_name}"],
      }
    }
  }
}

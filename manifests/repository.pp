# A description of what this defined type does
#
# @summary A short summary of the purpose of this defined type.
#
# @example
#   duplicacy::repository { 'my-repo':
#       $path => '/path/to/the/directory',
#       $user => 'me',
#       $
#   }
#
# @param id [String]
#   The name of this particular repository.
#
# @param path [String]
#   Absolute path to the directory to be backed up. Note that backup directories
#   should not be nested. 
#
# @param user [String]
#   The name of the user who owns this repository for a given server. This user
#   will also run the cron jobs for that system. Defaults to 'root'.
# 
# @param storage [Hash]
#   A hash of duplicacy::storage types against which this repo should be
#   initialized. Note that there must be an entry named 'default'.
define duplicacy::repository (
  String $repo_id = $name,
  String $path = undef,
  String $user = 'root',
  Hash[String, Variant[String, Hash[String, Variant[String, Integer]]]] $storage_targets = [],
  Optional[Array[String]] $filter_targets = [],
  Optional[String] $pref_dir = undef,
) {
  # TODO - actually really support alternate pref_dirs
  if !$pref_dir {
    $pref_dir = "${path}/.duplicacy"
  }

  # Initialize Storage
  if ! 'default' in $storage_targets {
    fail('A storage target named \'default\' must be defined!')
  }
  $storage_targets.each | $target, $params | {
    duplicacy::storage { $target:
      * => $params
    }
  }

  # Configure filters
  unless empty($filter_targets) {
    duplicacy::filter { "${repo_id}_filters":
      pref_dir       => $pref_dir,
      user           => $user,
      filter_targets => $filter_targets,
      requires       => [
        Storage['default'],
      ],
    }
  }
  # TODO - Schedule Backups

  # TODO - Schedule Prunes
}

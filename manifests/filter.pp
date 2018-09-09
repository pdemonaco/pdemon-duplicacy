# This type takes an ordered list of duplicity filter rules and inserts them
# into the filters file for a specific repository. For more detail on the filter
# rules see the [duplicacy
# wiki](https://github.com/gilbertchen/duplicacy/wiki/Include-Exclude-Patterns).
#
# @summary Creates a filters file for this repository.
#
# @example
#   duplicacy::filter { 'my-repo_filters':
#     pref_dir       => '/my/repo/dir/.duplicacy',
#     user           => 'me',
#     rules => [ 
#       '+foo/bar/*',
#       '-*',
#     ],
#   }
#
# @param pref_dir [String]
#   Path to the '.duplicacy' directory in which this filters file should be
#   defined.
#
# @param user [String]
#   Who should own this file? Typically this is also who runs the backups and
#   owns the associated data.
#
# @param rules [Array[String]]
#   An array of strings which each correspond to a line of the filter file. See
#   the https://github.com/gilbertchen/duplicacy/wiki/Include-Exclude-Patterns
#   page for more detail.
define duplicacy::filter(
  String $pref_dir = undef,
  String $user = undef,
  Array[String] $rules = [],
) {
  # 
  if empty($rules) {
    fail('At least one filter entry must be provided!')
  }

  # Make sure the file in question exists!
  $filter_file = "${pref_dir}/filters"
  file { $filter_file:
    ensure => file,
    owner  => $user,
    group  => $user, # assume same as owner
    mode   => '0644',
  }

  # Create all of the specified rules
  $rules.each | $index, $value | {
    # All but the first rule depend on previous rules
    if ($index == 0) {
      file_line { "rule_${index}":
        path    => $filter_file,
        line    => $value,
        require => [
          File[$filter_file],
        ],
      }
    } else {
      $previous = $index - 1
      file_line { "rule_${index}":
        path    => $filter_file,
        line    => $value,
        require => [
          File[$filter_file],
          File_line["rule_${previous}"],
        ],
      }
    }
  }
}

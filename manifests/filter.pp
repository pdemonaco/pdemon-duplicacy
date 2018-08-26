# A description of what this defined type does
#
# @summary A short summary of the purpose of this defined type.
#
# @example
#   duplicacy::filter { 'my-repo_filters':
#     $pref_dir       => '/my/repo/dir/.duplicacy',
#     $user           => 'me',
#     $filter_entries => [ 
#       '+foo/bar/*',
#       '-*',
#     ],
#   }
#
# @pref_dir [String]
#   Path to the '.duplicacy' directory in which this filters file should be
#   defined.
#
# @user [String]
#   Who should own this file? Typically this is also who runs the backups and
#   owns the associated data.
#
# @filter_entries [Array]
#   An array of strings which each correspond to a line of the filter file. See
#   the https://github.com/gilbertchen/duplicacy/wiki/Include-Exclude-Patterns
#   page for more detail.
define duplicacy::filter(
  String $pref_dir = undef,
  String $user = undef,
  Array[String] $filter_entries = [],
) {

  # Make sure the file in question exists!
  $filter_file = "${pref_dir}/filters"
  file { $filter_file:
    ensure => file,
    owner  => $user,
    group  => $user, # assume same as owner
    mode   => '0644',
  }

  # Create all of the specified rules
  $filter_entries.each | $index, $value | {
    $rule_name = "filter_rule_${index}"
    file_line { $rule_name:
      path    => $filter_file,
      line    => $value,
      require => [
        File[$filter_file],
      ],
    }
  }
}

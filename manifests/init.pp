# A class to configure and manage duplicacy backup instances.
#
# @summary 
#    This class manages the deployment of Duplicacy on a server.
#
# @example
#   include duplicacy
#
# @param package_name [Array[String]]
#   Package or list of packages needed to install duplicacy on this host.
#
# @param mail_package_name [Array[String]]
#   Package or list of packages needed to send email from this host.
#
# @param local_repos [Array[String]]
#   List of repo names which should be deployed on this machine. Note that
#   each repo must be defined in the `repos` parameter.
#
# @param repos [Hash]
#   A Hash where the keys are the names of the repositories to be deployed on
#   this system are stored. This is a very deep structure.
class duplicacy (
  Array[String] $package_name,
  Array[String] $mail_package_name,
  Array[String] $local_repos,
  Hash[String, Hash[String, Variant[String, Hash[String, Variant[String,
  Hash[String, Variant[String, Hash[String, Variant[String, Integer]]]]]],
  Array[String], Array[Hash[String, Variant[String, Integer, Hash[String,
  Variant[String, Integer]]]]]]]] $repos = {},
) {
  # Ensure the duplicacy package is present
  package { $duplicacy::package_name:
    ensure => present
  }

  # Ensure the mail client is present (mutt)
  package { $duplicacy::mail_package_name:
    ensure => present
  }

  # Create repositories
  $local_repos.each | $repo_id | {
    if $repo_id in $repos {
      duplicacy::repository { $repo_id:
        * => $repos[$repo_id],
      }
    } else {
      notify { "Skipping undefined repo: ${repo_id}": }
    }
  }
}

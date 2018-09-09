# A class to configure and manage duplicacy backup instances.
#
# @summary 
#    This class manages the deployment of Duplicacy on a server.
#
# @example
#   include duplicacy
#
# @param package_name [Array[String]]
#   Package or list of packages needed for this particular target system.
#
# @param mail_package_name [Optional[Array[String]]]
#   Package or list of packages needed for this particular target system.
#
# @param repos [Hash]
#   A Hash where the keys are the names of the repositories which should be
#   managed and the values are a Hash of the repositories parameters.
class duplicacy (
  Array[String] $package_name,
  Array[String] $mail_package_name,
  Hash[String, Hash[String, Variant[String, Hash[String, String]]]] $repos = {},
) {
  # Ensure the duplicacy package is present
  package { $duplicacy::package_name:
    ensure => present
  }

  # Ensure the mail client is present (mutt)
  package { $duplicacy::mail_package_name:
    ensure => present
  }

  # TODO - Create repositories
}

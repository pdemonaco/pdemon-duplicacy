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
# @param repos [Hash]
#   A Hash where the keys are the names of the repositories to be deployed on
#   this system are stored.
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

  # Create repositories

}

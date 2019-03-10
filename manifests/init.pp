# A class to configure and manage duplicacy backup instances.
#
# @summary 
#    This class manages the deployment of Duplicacy on a server.
#
# @example Configuring a local repo for root's home directory which is backed up once every hour
#   duplicacy {
#     local_repos          => [ 'root-home' ],
#     repos                => {
#       root-home          => {
#         repo_path        => '/root',
#         user             => 'root',
#         storage_targets  => {
#           default        => {
#             target       => {
#               url        => 'b2://pdemon-duplicacy-test',
#               b2_id      => 'my-b2-id-is-a-secret',
#               b2_app_key => 'so is my key'
#             },
#             encryption => {
#               password => 'my-secret-password'
#             },
#           },
#         },
#         backup_schedules => {
#           hourly => {
#             storage_name => 'default',
#             cron_entry   => {
#               'minute'   => '30',
#             },
#             'threads'         => 4,
#             'email_recipient' => phil@demona.co,
#           },
#         },
#         prune_schedules          => {
#           retain-7d1d-30d1w-90d0 => {
#             storage_name         => default,
#             schedules            => {
#               daily-prune        => {
#                 cron_entry       => {
#                   repo_id        => 'my-repo',
#                   hour           => '0',
#                 },
#               },
#             },
#             keep_ranges     => {
#               { interval => 0, max_age  => 90 },
#               { interval => 7, max_age  => 30 },
#               { interval => 1, max_age  => 7 },
#             },
#             threads         => 6,
#             email_recipient => 'phil@demona.co',
#           },
#         },
#       },
#     },
#   }
#
# @param package_name
#   Package or list of packages needed to install duplicacy on this host.
#
# @param mail_package_name
#   Package or list of packages needed to send email from this host.
#
# @param local_repos
#   List of repo names which should be deployed on this machine. Note that
#   each repo must be defined in the `repos` parameter.
#
# @param repos
#   A Hash where the keys are the names of the repositories to be deployed on
#   this system are stored. This is a very deep structure.
#
class duplicacy (
  Array[String] $package_name,
  Array[String] $mail_package_name,
  Array[String] $local_repos,
  Hash[String, Duplicacy::RepositoryEntry] $repos = {},
) {
  # Ensure the duplicacy package is present
  package { $duplicacy::package_name:
    ensure => present,
  }

  # Ensure the mail client is present (mutt)
  package { $duplicacy::mail_package_name:
    ensure => present,
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

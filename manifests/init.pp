# A class to configure and manage duplicacy backup instances.
#
# @summary 
#    This class manages the deployment of Duplicacy on a server.
#
# @example
#   include duplicacy
#
# @param repos [Hash]
#   A Hash where the keys are the names of the repositories which should be
#   managed and the values are a Hash of the repositories parameters.
class duplicacy (
  Boolean $manage_pruning = false,
  Hash[String, Hash[String, Variant[String, Hash[String, String]]]] $repos = {},
) {
  # TODO - Ensure the duplicacy package is present
  # TODO - Create repositories
}

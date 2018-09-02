# Each repository must have at least one storage backend defined. This
# define handles the initialization of a repository against a specific backend.
#
# @summary This initializes a storage backend for a particular duplicacy repository.
#
# @example
#   duplicacy::storage { 'my-repo_default':
#     storage_name         => 'default',
#     repo_id              => 'my-repo',
#     path                 => '/mnt/backup/my/directory',
#     target               => {
#       url                => 'b2://duplicacy-primary',
#       b2_id      => 'my-account-id-here',
#       b2_app_key => 'this-app-key-here',
#     },
#     encryption    => {
#       password    => 'super-secret-password',
#       iterations  => 16384,
#     },
#     chunk_parameters => {
#       size   => 4194304,
#       max    => 16777216,
#       min    => 1048576,
#     },
#   }
#
# @param $storage_name [String]
#   Name of this particular storage backend as referenced by duplicacy for this
#   specific repository. Note that the backend named 'default' is the primary.
#
# @param $repo_id [String]
#   ID referencing this repository on the target storage backend. 
#
# @param $path [String]
#   Directory in which this particular repository resides on this machine. 
#
# @param encrption [Hash]
#   This hash includes two key parameters related to encryption.
#     * `password` - this is the password used to encrypt the config file
#     * `iterations` - the number of iterations to generate the block password.
#     this is optional and defaults to 16384
# 
#   If this hash is absent the data will not be encrypted.
#   See https://github.com/gilbertchen/duplicacy/wiki/Encryption for more
#   details.
#
# @param target [Hash]
#   Hash containing a number of details for the target system. Currently only b2
#   is supported by this module.
#     * 'url' - the url to provide to the init command
#
#   b2 specific arguments
#     * `b2_id` - ID from your b2 account
#     * `b2_app_key` - the application key you generated for this bucket
#
# @param chunk_parameters [Hash]
#   This hash includes three parameters defining how chunks are handled. The
#   entire hash is optional, as are the sub components.
#     * `size` - The target size of each chunk - defaults to 4M
#     * `max` - largest possible chunk size - defaults to $size * 4
#     * `min` - smallest possible chunk size - defaults to $size / 4
define duplicacy::storage (
  String $storage_name = undef,
  String $repo_id = undef,
  String $path = undef,
  Hash[String, Variant[String, Integer]] $target = {},
  Optional[Hash[String, Variant[String, Integer]]] $encryption = {},
  Optional[Hash[String, Integer]] $chunk_parameters = {},
) {
  if ($storage_name == 'default') {
    $default_storage = true
    $env_prefix = 'DUPLICACY'
  } else {
    $default_storage = false
    $env_prefix = "DUPLICACY_${storage_name}"
  }

  # Declare the base command
  $cmd_base = '/usr/bin/duplicacy init'

  # Process encryption parameters
  if !empty($encryption) {
    # Extract the password, this is mandatory
    if 'password' in $encryption {
      $password = $encryption['password']
      $env_encryption = [ "${env_prefix}_PASSWORD=${password}" ]
    } else {
      fail('Password mandatory when encryption is enabled!')
    }

    if 'iterations' in $encryption {
      $iterations = $encryption['iterations']
      $cmd_encryption = " -e -iterations ${iterations}"
    } else {
      $cmd_encryption = ' -e'
    }
  } else {
    $cmd_encryption = ''
    $env_encryption = []
  }

  # Process chunk arguments
  if !empty($chunk_parameters) {
    # Default the size to 4 MiB
    if 'size' in $chunk_parameters {
      $chunk_size = $chunk_parameters['size']
    } else {
      $chunk_size = 4194304
    }

    # Default the max to size * 4
    if 'max' in $chunk_parameters {
      $chunk_size_max = $chunk_parameters['max']
    } else {
      $chunk_size_max = $chunk_size * 4
    }

    # Default the min to size / 4
    if 'min' in $chunk_parameters {
      $chunk_size_min = $chunk_parameters['min']
    } else {
      $chunk_size_min = $chunk_size / 4
    }
    $cmd_chunks = " -c ${chunk_size} -max ${chunk_size_max} -min ${chunk_size_min}"
  } else {
    $cmd_chunks = ''
  }

  # Process storage URL
  if empty($target) {
    fail('$target is mandatory!')
  }

  # Capture the URL type
  if 'url' in $target {
    $storage_url = $target['url']
  } else {
    fail('$url subkey of $target is mandatory!')
  }

  # Determine the backend type
  # See https://github.com/gilbertchen/duplicacy/wiki/Storage-Backends for
  # details
  case $storage_url {
    /^b2:/: {
      if !('b2_id' in $target) {
        fail("\$b2_id is mandatory for ${storage_url}")
      } elsif !('b2_app_key' in $target) {
        fail("\$b2_app_key is mandatory for ${storage_url}")
      }
      $b2_id = $target['b2_id']
      $b2_app_key = $target['b2_app_key']
      $env_storage = [
        "${env_prefix}_B2_ID=${b2_id}",
        "${env_prefix}_B2_KEY=${b2_app_key}"
      ]
      $cmd_args = " ${storage_name} ${storage_url}"
    }
    default: {
      fail("Unrecognized url: ${storage_url}")
    }
  }

  # Initialize the storage for this repository
  $repo_init_command = "${cmd_base}${cmd_encryption}${cmd_chunks}${cmd_args}"
  $repo_init_env = $env_encryption + $env_storage
  exec { "init_${repo_id}_${storage_name}":
    command     => $repo_init_command,
    cwd         => $path,
    creates     => "${path}/cache/${storage_name}",
    environment => $repo_init_env,
  }
}

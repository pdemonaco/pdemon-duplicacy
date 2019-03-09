# Hash containing a number of details for the target system. Currently only b2
# is supported by this module.
# * 'url' - the url to provide to the init command
#
# b2 specific arguments
# * `b2_id` - ID from your b2 account
# * `b2_app_key` - the application key you generated for this bucket
type Duplicacy::StorageTargetB2 = Hash[
  Enum[
    'url',
    'b2_id',
    'b2_app_key',
  ],
  String,
]

type Duplicacy::StorageEncryption = Hash[
  Enum[
    'password',
    'iterations',
  ],
  Variant[
    String,
    Integer,
  ],
]

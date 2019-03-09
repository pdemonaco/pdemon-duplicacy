type Duplicacy::StorageTarget = Hash[
  Enum[
    'target',
    'encryption',
    'chunk_parameters',
  ],
  Variant[
    Duplicacy::StorageTargetType,
    Duplicacy::StorageEncryption,
    Duplicacy::StorageChunkParams,
  ],
]

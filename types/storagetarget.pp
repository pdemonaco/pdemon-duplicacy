type Duplicacy::StorageTarget = Struct[
  target                     => Duplicacy::StorageTargetType,
  Optional[encryption]       => Duplicacy::StorageEncryption,
  Optional[chunk_parameters] => Duplicacy::StorageChunkParams,
]

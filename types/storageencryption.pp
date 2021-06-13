# @summary Configure encryption for the given storage
type Duplicacy::StorageEncryption = Struct[
  password             => String,
  Optional[iterations] => Integer,
]

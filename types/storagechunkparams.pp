# @summary Configure the attributes of chunks for this storage target
type Duplicacy::StorageChunkParams = Struct[
  Optional[size] => Integer,
  Optional[max]  => Integer,
  Optional[min]  => Integer,
]

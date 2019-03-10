type Duplicacy::PruneSchedule = Hash[
  Enum[
    'storage_name',
    'schedules',
    'exhaustive',
    'keep_ranges',
    'backup_tags',
    'threads',
    'email_recipient',
  ],
  Variant[
    String,
    Hash[String, Duplicacy::PruneScheduleEntry],
    Boolean,
    Array[Duplicacy::KeepRange],
    Array[String],
    Integer,
  ],
]

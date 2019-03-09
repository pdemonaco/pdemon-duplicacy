type Duplicacy::RepositoryEntry = Hash[
  Enum[
    'repo_path',
    'repo_id',
    'user',
    'storage_targets',
    'backup_schedules',
    'prune_schedules',
    'filter_rules',
    'log_retention',
  ],
  Variant[
    String,
    Hash[String, Duplicacy::StorageTarget],
    Hash[String, Duplicacy::PruneSchedule],
    Array[String],
  ],
]

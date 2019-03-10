type Duplicacy::PruneScheduleEntry = Hash[
  Enum[
    'repo_id',
    'storage_name',
    'cron_entry',
  ],
  Variant[
    String,
    Duplicacy::ScheduleEntry,
  ],
]

type Duplicacy::BackupSchedule = Hash[
  Enum[
    'storage_name',
    'cron_entry',
    'backup_tag',
    'threads',
    'hash_mode',
    'limit_rate',
    'email_recipient',
  ],
  Variant[
    String,
    Duplicacy::ScheduleEntry,
    Integer,
    Boolean,
  ],
]

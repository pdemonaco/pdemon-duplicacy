type Duplicacy::BackupSchedule = Struct[
  storage_name              => String,
  cron_entry                => Duplicacy::ScheduleEntry,
  Optional[backup_tag]      => String,
  Optional[threads]         => Integer,
  Optional[hash_mode]       => Boolean,
  Optional[limit_rate]      => Integer,
  Optional[email_recipient] => String,
]

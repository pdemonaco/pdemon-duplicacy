type Duplicacy::PruneSchedule = Struct[
  schedules                 => Hash[String, Duplicacy::PruneScheduleEntry],
  Optional[exhaustive]      => Boolean,
  keep_ranges               => Array[Duplicacy::KeepRange],
  Optional[backup_tags]     => Array[String],
  Optional[threads]         => Integer,
  Optional[email_recipient] => Duplicacy::EmailRecipient,
]

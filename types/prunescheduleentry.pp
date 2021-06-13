type Duplicacy::PruneScheduleEntry = Struct[
  Optional[repo_id]      => String,
  Optional[storage_name] => String,
  cron_entry             => Duplicacy::ScheduleEntry,
]

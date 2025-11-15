# @summary Schedule prune jobs against this or other repos in the same storage
type Duplicacy::PruneScheduleEntry = Struct[
  Optional[repo_id]      => Duplicacy::SnapshotID,
  Optional[storage_name] => String,
  cron_entry             => Duplicacy::ScheduleEntry,
]

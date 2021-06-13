# @summary Configures a directory as a duplicacy backup repository
type Duplicacy::RepositoryEntry = Struct[
  repo_path                  => Stdlib::AbsolutePath,
  Optional[repo_id]          => Duplicacy::SnapshotID,
  user                       => String,
  storage_targets            => Hash[String, Duplicacy::StorageTarget],
  Optional[backup_schedules] => Hash[String, Duplicacy::BackupSchedule],
  Optional[prune_schedules]  => Hash[String, Duplicacy::PruneSchedule],
  Optional[filter_rules]     => Array[String],
  Optional[log_retention]    => String,
]

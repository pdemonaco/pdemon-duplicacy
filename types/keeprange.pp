# @param interval
#   One snapshot will be kept for each interval of this length in days
#
# @param min_age
#   This policy applies to snapshots at least this number of days old
#
# @summary Prune job parameters
type Duplicacy::KeepRange = Struct[
  interval => Integer,
  min_age  => Integer,
]

# @summary A basic alias for the cron resource type
type Duplicacy::ScheduleEntry = Hash[
  String,
  Variant[
    String,
    Integer,
    Array,
  ],
]

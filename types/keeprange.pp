type Duplicacy::KeepRange = Hash[
  Enum[
    'interval',
    'min_age',
  ],
  Variant[
    String,
    Integer,
  ],
]

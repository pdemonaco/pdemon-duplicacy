# @summary A valid email address
type Duplicacy::EmailRecipient = Pattern[/[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alnum:]]{2,}/]

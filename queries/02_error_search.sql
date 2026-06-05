fields @timestamp, @log, @message
| filter @message like /(?i)(error|fail|exception|crash|timeout)/
| sort @timestamp desc
| limit 50

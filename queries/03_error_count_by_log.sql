fields @timestamp, @log, @message
| filter @message like /(?i)(error|fail|exception|crash|timeout)/
| stats count(*) as errors by @log
| sort errors desc
| limit 20

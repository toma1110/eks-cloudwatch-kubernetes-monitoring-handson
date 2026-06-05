fields @timestamp, @message
| parse @message /"(?<method>GET|POST|PUT|DELETE|PATCH) (?<path>[^ ]+) [^"]+" (?<status>\d{3})/
| filter ispresent(status)
| stats count(*) as requests by status
| sort requests desc

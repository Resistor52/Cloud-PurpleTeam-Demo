# Insights

## CloudWatch Logs Insights

### Port Scanning

**log group:** khartman-demo1-flowlogs

```
fields @timestamp,dstPort
| filter dstAddr like '172.31.42.53'
| stats count(*) as cnt  by  dstPort
| sort dstPort

```

### All HTTP Logs

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`
| filter  `user-agent` not like /ELB-HealthChecker/ and  `user-agent` not like /AWS Security Scanner/
| sort @timestamp desc
```

Let's isolate the logs that bypassed the Load Balancer.

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`
| filter  `user-agent` not like /ELB-HealthChecker/ and  `user-agent` not like /AWS Security Scanner/ and `forwarded-ip` = '-'
| sort @timestamp
```


### Nikto Scanning

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`
| filter `user-agent` like 'Mozilla/5.00 (Nikto/2.1.6)'
| sort @timestamp
```

**log group:** error_log

fields `message` | stats count(*) as cnt by `message` | sort cnt desc

### WPScan

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`
| filter  `user-agent` like 'WPScan v3.8.6 (https://wpscan.org/)'
| sort @timestamp desc
```

**log group:** error_log

```
fields `message` | stats count(*) as cnt by `message` | sort cnt desc
```

**log group:** khartman-demo1-flowlogs

```
fields @timestamp,dstPort
| filter dstAddr like '172.31.42.53' and dstPort = '80'
```

### FTP Brute Force
**log group:** khartman-demo1-flowlogs

```
fields @timestamp,dstPort
| filter dstAddr like '172.31.42.53' and dstPort = '21'
```

**log group:** vsftpd_log

```
fields @timestamp, @message
| filter @message like /USER/
```

### Weevley

#### Data Exfiltration

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`, `bytes-sent`, `bytes-received`
| filter  `user-agent` not like /ELB-HealthChecker/ and  `user-agent` not like /AWS Security Scanner/ and `forwarded-ip` = '-'
| sort @timestamp
```

or

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`, `bytes-sent`, `bytes-received`
| filter  `bytes-sent` > '1000'
| sort @timestamp
```

#### Scanning

**log group:** access_log

```
fields @timestamp, `client-ip`, `forwarded-ip`, `status`, `request`, `query`, `user-agent`, `bytes-sent`, `bytes-received`
| filter  `user-agent` not like /ELB-HealthChecker/ and  `user-agent` not like /AWS Security Scanner/ and `forwarded-ip` = '-'
| sort @timestamp
```

**log group:** khartman-demo1-flowlogs
```
fields @timestamp, @message
| filter srcAddr like '172.31.42.53'
```

```
fields @timestamp, dstPort
| filter srcAddr like '172.31.42.53' and dstPort < '666' and dstPort !='80' and dstPort !='443' and dstPort != '123'
```


### Beaconing

**log group:** cron

```
fields @timestamp, @message
| sort @timestamp desc
| limit 20
```

**log group:** khartman-demo1-flowlogs

```
fields @timestamp, @message
| filter srcAddr like '172.31.42.53' and dstPort = '666'
```

### Load Balancer Logs  

Athena

```
SELECT *
FROM alb_logs
LIMIT 100
```

```
SELECT client_ip, request_verb, request_url, user_agent, target_status_code_list
FROM alb_logs
LIMIT 100
```

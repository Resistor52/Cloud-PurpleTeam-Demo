# insights

## CloudWatch Logs Insights

### Port Scanning

log group: khartman-demo1-flowlogs

```
fields @timestamp,dstPort
| filter dstAddr like '172.31.12.211'
| stats count(*) as cnt  by  dstPort
| sort dstPort

```

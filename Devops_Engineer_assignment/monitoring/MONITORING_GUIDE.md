# Monitoring & Observability Guide

## 📊 **Complete Monitoring Stack**

### **ELK Stack (Logging)**
- **Elasticsearch**: Distributed search and analytics engine
- **Logstash**: Data processing pipeline for log ingestion
- **Kibana**: Visualization and dashboard interface
- **Filebeat**: Lightweight log shipper from containers

### **Metrics & Alerting**
- **Prometheus**: Time-series metrics collection
- **Grafana**: Metrics visualization and dashboards
- **AlertManager**: Alert routing and notification

### **Tracing**
- **Jaeger**: Distributed tracing (via Istio)
- **Istio Service Mesh**: Automatic trace generation

## 🔍 **Logging Architecture**

### **Log Flow**
```
Container Logs → Filebeat → Logstash → Elasticsearch → Kibana
     ↓              ↓          ↓           ↓           ↓
  /var/log      DaemonSet   Processing   Storage   Visualization
```

### **Log Sources**
- **Application Logs**: FastAPI structured logs
- **Kubernetes Logs**: Pod, service, ingress logs
- **Istio Logs**: Service mesh traffic logs
- **Infrastructure Logs**: Node and system logs

### **Log Retention Policy**
- **Hot Phase**: 7 days (fast storage)
- **Warm Phase**: 23 days (slower storage)
- **Delete Phase**: After 30 days total

## 📈 **Metrics Collection**

### **Application Metrics**
```yaml
# RED Metrics
- Request Rate: requests_per_second
- Error Rate: error_percentage
- Duration: response_time_percentiles

# Business Metrics
- Jobs Processed: jobs_total_counter
- Queue Depth: queue_size_gauge
- Active Users: active_users_gauge
```

### **Infrastructure Metrics**
```yaml
# Kubernetes Metrics
- Pod CPU/Memory: container_cpu_usage, container_memory_usage
- Node Resources: node_cpu_utilization, node_memory_utilization
- Cluster Health: kube_pod_status, kube_deployment_status

# AWS Metrics
- RDS Performance: database_connections, query_duration
- ElastiCache: redis_connected_clients, redis_memory_usage
- ALB Metrics: target_response_time, healthy_host_count
```

## 🚨 **Alerting Rules**

### **Critical Alerts**
```yaml
# Service Down
- alert: ServiceDown
  expr: up{job="data-collection-service"} == 0
  for: 5m
  severity: critical

# High Error Rate
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 2m
  severity: critical

# Database Connection Failure
- alert: DatabaseDown
  expr: postgresql_up == 0
  for: 1m
  severity: critical
```

### **Warning Alerts**
```yaml
# High Latency
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
  for: 5m
  severity: warning

# High Memory Usage
- alert: HighMemoryUsage
  expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.8
  for: 10m
  severity: warning
```

## 📱 **Dashboards**

### **Grafana Dashboards**
1. **Application Overview**
   - Request rate, error rate, latency
   - Job processing metrics
   - API endpoint performance

2. **Infrastructure Health**
   - Kubernetes cluster status
   - Node resource utilization
   - Pod health and restarts

3. **Database Performance**
   - Connection pool status
   - Query performance
   - Slow query analysis

4. **Security Monitoring**
   - WAF blocked requests
   - Authentication failures
   - Suspicious activity patterns

### **Kibana Dashboards**
1. **Application Logs**
   - Error log analysis
   - Request tracing
   - Performance bottlenecks

2. **Security Logs**
   - Failed authentication attempts
   - Blocked requests
   - Anomaly detection

3. **Operational Logs**
   - Deployment events
   - Configuration changes
   - System alerts

## 🔧 **Setup Instructions**

### **Deploy ELK Stack**
```bash
# Using Helm
./scripts/setup-elk-stack.sh helm

# Using Manifests
./scripts/setup-elk-stack.sh manifests

# Verify installation
kubectl get pods -n logging
```

### **Deploy Prometheus & Grafana**
```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Apply custom configurations
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/grafana-dashboard.json
```

### **Access Dashboards**
```bash
# Kibana
https://logs-{env}.datacollection.com

# Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
http://localhost:3000

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
http://localhost:9090
```

## 🔍 **Log Analysis Examples**

### **Application Error Investigation**
```bash
# Search for errors in Kibana
service:data-collection-service AND log_level:ERROR

# Filter by time range and request ID
@timestamp:[now-1h TO now] AND request_id:"abc-123-def"

# Aggregate error patterns
service:data-collection-service AND log_level:ERROR | stats count by log_message
```

### **Performance Analysis**
```bash
# Slow requests in Kibana
service:data-collection-service AND response_time:>2000

# Database slow queries
service:data-collection-service AND log_message:*"slow query"*

# Memory usage patterns
container_memory_usage_bytes{pod=~"data-collection-.*"}
```

## 📊 **Metrics Queries**

### **Prometheus Queries**
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate percentage
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod CPU usage
rate(container_cpu_usage_seconds_total{pod=~"data-collection-.*"}[5m])

# Database connections
postgresql_stat_database_numbackends
```

## 🚀 **Best Practices**

### **Logging Best Practices**
- Use structured logging (JSON format)
- Include correlation IDs for request tracing
- Log at appropriate levels (ERROR, WARN, INFO, DEBUG)
- Avoid logging sensitive information
- Use consistent timestamp formats

### **Metrics Best Practices**
- Use meaningful metric names
- Add relevant labels for filtering
- Monitor both technical and business metrics
- Set appropriate alert thresholds
- Avoid high-cardinality labels

### **Dashboard Best Practices**
- Group related metrics together
- Use consistent time ranges
- Add context with annotations
- Include SLA/SLO indicators
- Make dashboards self-explanatory

## 🔧 **Troubleshooting**

### **Common Issues**
1. **Logs not appearing in Kibana**
   - Check Filebeat DaemonSet status
   - Verify Logstash processing
   - Check Elasticsearch cluster health

2. **High memory usage in Elasticsearch**
   - Adjust JVM heap size
   - Implement proper index lifecycle management
   - Monitor shard allocation

3. **Missing metrics in Grafana**
   - Verify Prometheus scrape targets
   - Check service discovery configuration
   - Validate metric endpoint accessibility

### **Health Checks**
```bash
# Check ELK Stack health
kubectl get pods -n logging
curl -s "elasticsearch-client.logging.svc.cluster.local:9200/_cluster/health"

# Check Prometheus targets
curl -s "prometheus.monitoring.svc.cluster.local:9090/api/v1/targets"

# Verify log ingestion
curl -s "elasticsearch-client.logging.svc.cluster.local:9200/_cat/indices?v"
```

This monitoring setup provides comprehensive observability across all layers of the infrastructure and application stack.
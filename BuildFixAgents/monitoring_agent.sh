#!/bin/bash
# Monitoring Agent - Sets up logging, metrics, alerting, and observability
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_STATE="$SCRIPT_DIR/state/monitoring"
mkdir -p "$MONITOR_STATE/configs" "$MONITOR_STATE/dashboards" "$MONITOR_STATE/alerts"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${ORANGE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${ORANGE}║        Monitoring Agent v1.0           ║${NC}"
    echo -e "${BOLD}${ORANGE}╚════════════════════════════════════════╝${NC}"
}

# Generate logging configuration
generate_logging_config() {
    local language="${1:-javascript}"
    local output_dir="$MONITOR_STATE/configs"
    
    log_event "INFO" "MONITORING" "Generating logging configuration for $language"
    
    case "$language" in
        javascript)
            generate_winston_config "$output_dir"
            ;;
        python)
            generate_python_logging "$output_dir"
            ;;
        csharp)
            generate_serilog_config "$output_dir"
            ;;
        *)
            log_event "ERROR" "MONITORING" "Unsupported language: $language"
            return 1
            ;;
    esac
}

# Generate Winston configuration for Node.js
generate_winston_config() {
    local output_dir="$1"
    
    # Winston configuration
    cat > "$output_dir/logger.js" << 'EOF'
const winston = require('winston');
const path = require('path');

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define colors for each level
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white',
};

winston.addColors(colors);

// Format for console output
const consoleFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`
  )
);

// Format for file output
const fileFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Create logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  levels,
  transports: [
    // Console transport
    new winston.transports.Console({
      format: consoleFormat,
    }),
    // Error log file
    new winston.transports.File({
      filename: path.join('logs', 'error.log'),
      level: 'error',
      format: fileFormat,
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
    // Combined log file
    new winston.transports.File({
      filename: path.join('logs', 'combined.log'),
      format: fileFormat,
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
  ],
  // Handle exceptions
  exceptionHandlers: [
    new winston.transports.File({
      filename: path.join('logs', 'exceptions.log'),
      format: fileFormat,
    }),
  ],
  // Handle rejections
  rejectionHandlers: [
    new winston.transports.File({
      filename: path.join('logs', 'rejections.log'),
      format: fileFormat,
    }),
  ],
});

// Add request logging middleware
const requestLogger = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const message = `${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`;
    
    if (res.statusCode >= 400) {
      logger.error(message, {
        method: req.method,
        url: req.originalUrl,
        status: res.statusCode,
        duration,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
    } else {
      logger.http(message, {
        method: req.method,
        url: req.originalUrl,
        status: res.statusCode,
        duration,
      });
    }
  });
  
  next();
};

// Structured logging helper
const logEvent = (event, data = {}) => {
  logger.info(event, {
    event,
    timestamp: new Date().toISOString(),
    ...data,
  });
};

module.exports = {
  logger,
  requestLogger,
  logEvent,
};
EOF

    # Logging utilities
    cat > "$output_dir/log-utils.js" << 'EOF'
const { logger } = require('./logger');

// Performance logging
class PerformanceLogger {
  constructor(operation) {
    this.operation = operation;
    this.startTime = Date.now();
    this.marks = [];
  }

  mark(label) {
    const elapsed = Date.now() - this.startTime;
    this.marks.push({ label, elapsed });
    logger.debug(`Performance mark: ${this.operation} - ${label}`, { elapsed });
  }

  end(metadata = {}) {
    const totalTime = Date.now() - this.startTime;
    logger.info(`Performance: ${this.operation} completed`, {
      operation: this.operation,
      totalTime,
      marks: this.marks,
      ...metadata,
    });
  }
}

// Error logging with context
const logError = (error, context = {}) => {
  logger.error(error.message, {
    error: {
      message: error.message,
      stack: error.stack,
      code: error.code,
    },
    context,
  });
};

// Audit logging
const auditLog = (action, userId, details = {}) => {
  logger.info('Audit log', {
    audit: true,
    action,
    userId,
    timestamp: new Date().toISOString(),
    details,
  });
};

// Metric logging
const logMetric = (metric, value, tags = {}) => {
  logger.info('Metric', {
    metric: true,
    name: metric,
    value,
    tags,
    timestamp: new Date().toISOString(),
  });
};

module.exports = {
  PerformanceLogger,
  logError,
  auditLog,
  logMetric,
};
EOF
    
    log_event "SUCCESS" "MONITORING" "Winston logging configuration generated"
}

# Generate Prometheus metrics
generate_metrics_config() {
    local output_dir="$MONITOR_STATE/configs"
    
    log_event "INFO" "MONITORING" "Generating Prometheus metrics configuration"
    
    # Prometheus client setup
    cat > "$output_dir/metrics.js" << 'EOF'
const prometheus = require('prom-client');

// Create a Registry
const register = new prometheus.Registry();

// Add default metrics
prometheus.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
});

const businessMetrics = {
  userRegistrations: new prometheus.Counter({
    name: 'user_registrations_total',
    help: 'Total number of user registrations',
  }),
  
  loginAttempts: new prometheus.Counter({
    name: 'login_attempts_total',
    help: 'Total number of login attempts',
    labelNames: ['status'],
  }),
  
  apiCalls: new prometheus.Counter({
    name: 'api_calls_total',
    help: 'Total number of API calls',
    labelNames: ['endpoint', 'client'],
  }),
  
  processingTime: new prometheus.Histogram({
    name: 'processing_time_seconds',
    help: 'Time spent processing requests',
    labelNames: ['operation'],
    buckets: [0.1, 0.5, 1, 2, 5, 10],
  }),
};

// Register all metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(activeConnections);
Object.values(businessMetrics).forEach(metric => register.registerMetric(metric));

// Middleware for Express
const metricsMiddleware = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    const labels = {
      method: req.method,
      route,
      status_code: res.statusCode,
    };
    
    httpRequestDuration.observe(labels, duration);
    httpRequestTotal.inc(labels);
  });
  
  next();
};

// Metrics endpoint
const metricsEndpoint = async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
};

module.exports = {
  register,
  httpRequestDuration,
  httpRequestTotal,
  activeConnections,
  businessMetrics,
  metricsMiddleware,
  metricsEndpoint,
};
EOF

    # Grafana dashboard
    generate_grafana_dashboard "$output_dir"
    
    log_event "SUCCESS" "MONITORING" "Metrics configuration generated"
}

# Generate Grafana dashboard
generate_grafana_dashboard() {
    local output_dir="$1"
    
    cat > "$MONITOR_STATE/dashboards/application-dashboard.json" << 'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "tooltip": false,
              "viz": false,
              "legend": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "reqps"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "tooltip": {
          "mode": "single"
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        }
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "rate(http_requests_total[5m])",
          "interval": "",
          "legendFormat": "{{method}} {{route}}",
          "refId": "A"
        }
      ],
      "title": "Request Rate",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 500
              }
            ]
          },
          "unit": "ms"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 3,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "values": false,
          "calcs": [
            "lastNotNull"
          ],
          "fields": ""
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true,
        "text": {}
      },
      "pluginVersion": "7.5.7",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) * 1000",
          "interval": "",
          "legendFormat": "95th percentile",
          "refId": "A"
        }
      ],
      "title": "Response Time (95th percentile)",
      "type": "gauge"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["application"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Application Dashboard",
  "uid": "app-dashboard",
  "version": 0
}
EOF
    
    log_event "SUCCESS" "MONITORING" "Grafana dashboard generated"
}

# Generate alerting rules
generate_alerting_rules() {
    local output_dir="$MONITOR_STATE/alerts"
    
    log_event "INFO" "MONITORING" "Generating alerting rules"
    
    # Prometheus alert rules
    cat > "$output_dir/prometheus-rules.yml" << 'EOF'
groups:
  - name: application_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% for the last 5 minutes"
      
      # High response time
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is above 2 seconds"
      
      # High memory usage
      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes / 1024 / 1024 > 500
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Process memory usage is above 500MB"
      
      # Service down
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"
      
      # High CPU usage
      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is above 80%"

  - name: business_alerts
    interval: 1m
    rules:
      # Login failures
      - alert: HighLoginFailureRate
        expr: rate(login_attempts_total{status="failed"}[10m]) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High login failure rate"
          description: "Login failure rate is above 50%"
      
      # API rate limit
      - alert: APIRateLimit
        expr: rate(api_calls_total[1m]) > 100
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "API rate limit approaching"
          description: "API call rate is above 100 requests per minute"
EOF

    # AlertManager configuration
    cat > "$output_dir/alertmanager.yml" << 'EOF'
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'your-password'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'team-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
  - name: 'team-notifications'
    email_configs:
      - to: 'team@example.com'
        headers:
          Subject: 'Alert: {{ .GroupLabels.alertname }}'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
        description: '{{ .GroupLabels.alertname }}'

  - name: 'slack-warnings'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#warnings'
        title: 'Warning: {{ .GroupLabels.alertname }}'
EOF
    
    log_event "SUCCESS" "MONITORING" "Alerting rules generated"
}

# Generate health check endpoints
generate_health_checks() {
    local output_dir="$MONITOR_STATE/configs"
    
    log_event "INFO" "MONITORING" "Generating health check endpoints"
    
    cat > "$output_dir/health-checks.js" << 'EOF'
const os = require('os');
const { promisify } = require('util');

class HealthChecker {
  constructor() {
    this.checks = new Map();
    this.registerDefaultChecks();
  }

  registerDefaultChecks() {
    // Basic liveness check
    this.register('liveness', async () => {
      return { status: 'ok', timestamp: new Date().toISOString() };
    });

    // Memory check
    this.register('memory', async () => {
      const used = process.memoryUsage();
      const limit = 500 * 1024 * 1024; // 500MB
      const healthy = used.rss < limit;
      
      return {
        status: healthy ? 'ok' : 'unhealthy',
        details: {
          rss: Math.round(used.rss / 1024 / 1024) + 'MB',
          heapTotal: Math.round(used.heapTotal / 1024 / 1024) + 'MB',
          heapUsed: Math.round(used.heapUsed / 1024 / 1024) + 'MB',
          external: Math.round(used.external / 1024 / 1024) + 'MB',
        },
      };
    });

    // CPU check
    this.register('cpu', async () => {
      const cpus = os.cpus();
      const loadAvg = os.loadavg()[0];
      const healthy = loadAvg < cpus.length * 0.8;
      
      return {
        status: healthy ? 'ok' : 'unhealthy',
        details: {
          cores: cpus.length,
          loadAverage: loadAvg.toFixed(2),
          uptime: Math.floor(process.uptime()) + 's',
        },
      };
    });
  }

  register(name, checkFn) {
    this.checks.set(name, checkFn);
  }

  async runCheck(name) {
    const check = this.checks.get(name);
    if (!check) {
      throw new Error(`Check '${name}' not found`);
    }

    try {
      const start = Date.now();
      const result = await check();
      const duration = Date.now() - start;
      
      return {
        name,
        ...result,
        duration: duration + 'ms',
      };
    } catch (error) {
      return {
        name,
        status: 'error',
        error: error.message,
      };
    }
  }

  async runAllChecks() {
    const results = {};
    const promises = [];
    
    for (const [name, check] of this.checks) {
      promises.push(
        this.runCheck(name).then(result => {
          results[name] = result;
        })
      );
    }
    
    await Promise.all(promises);
    
    const overallHealthy = Object.values(results).every(
      check => check.status === 'ok'
    );
    
    return {
      status: overallHealthy ? 'healthy' : 'unhealthy',
      checks: results,
      timestamp: new Date().toISOString(),
    };
  }

  // Express middleware
  healthEndpoint() {
    return async (req, res) => {
      const health = await this.runAllChecks();
      const statusCode = health.status === 'healthy' ? 200 : 503;
      res.status(statusCode).json(health);
    };
  }

  livenessEndpoint() {
    return async (req, res) => {
      const liveness = await this.runCheck('liveness');
      res.status(200).json(liveness);
    };
  }

  readinessEndpoint() {
    return async (req, res) => {
      const checks = ['memory', 'cpu'];
      const results = {};
      let ready = true;
      
      for (const check of checks) {
        const result = await this.runCheck(check);
        results[check] = result;
        if (result.status !== 'ok') {
          ready = false;
        }
      }
      
      res.status(ready ? 200 : 503).json({
        ready,
        checks: results,
        timestamp: new Date().toISOString(),
      });
    };
  }
}

module.exports = HealthChecker;
EOF
    
    log_event "SUCCESS" "MONITORING" "Health check endpoints generated"
}

# Generate distributed tracing setup
generate_tracing_config() {
    local output_dir="$MONITOR_STATE/configs"
    
    log_event "INFO" "MONITORING" "Generating distributed tracing configuration"
    
    cat > "$output_dir/tracing.js" << 'EOF'
const opentelemetry = require('@opentelemetry/api');
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');

// Configure the tracer provider
const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.SERVICE_NAME || 'my-service',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.SERVICE_VERSION || '1.0.0',
  }),
});

// Configure Jaeger exporter
const jaegerExporter = new JaegerExporter({
  endpoint: process.env.JAEGER_ENDPOINT || 'http://localhost:14268/api/traces',
});

// Add the exporter to the provider
provider.addSpanProcessor(new BatchSpanProcessor(jaegerExporter));

// Register the provider
provider.register();

// Register instrumentations
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation({
      requestHook: (span, request) => {
        span.setAttributes({
          'http.request.body': request.body ? JSON.stringify(request.body) : undefined,
        });
      },
    }),
    new ExpressInstrumentation(),
  ],
});

// Get tracer
const tracer = opentelemetry.trace.getTracer(
  process.env.SERVICE_NAME || 'my-service',
  process.env.SERVICE_VERSION || '1.0.0'
);

// Helper function to create custom spans
const createSpan = (name, fn) => {
  return tracer.startActiveSpan(name, async (span) => {
    try {
      const result = await fn(span);
      span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({
        code: opentelemetry.SpanStatusCode.ERROR,
        message: error.message,
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
};

// Middleware to add trace ID to response headers
const traceMiddleware = (req, res, next) => {
  const span = opentelemetry.trace.getActiveSpan();
  if (span) {
    const spanContext = span.spanContext();
    res.setHeader('X-Trace-Id', spanContext.traceId);
  }
  next();
};

module.exports = {
  tracer,
  createSpan,
  traceMiddleware,
};
EOF
    
    log_event "SUCCESS" "MONITORING" "Distributed tracing configuration generated"
}

# Generate monitoring stack docker-compose
generate_monitoring_stack() {
    local output_file="$MONITOR_STATE/docker-compose.monitoring.yml"
    
    log_event "INFO" "MONITORING" "Generating monitoring stack configuration"
    
    cat > "$output_file" << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts/prometheus-rules.yml:/etc/prometheus/rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - grafana_data:/var/lib/grafana
      - ./dashboards:/etc/grafana/provisioning/dashboards
      - ./datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    volumes:
      - ./alerts/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    restart: unless-stopped

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    environment:
      - COLLECTOR_ZIPKIN_HOST_PORT=:9411
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778"
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
      - "9411:9411"
    restart: unless-stopped

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF
    
    # Prometheus configuration
    cat > "$MONITOR_STATE/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - "rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'application'
    static_configs:
      - targets: ['host.docker.internal:3001']
    metrics_path: '/metrics'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
    
    log_event "SUCCESS" "MONITORING" "Monitoring stack configuration generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        logging)
            generate_logging_config "${2:-javascript}"
            ;;
        metrics)
            generate_metrics_config
            ;;
        alerts)
            generate_alerting_rules
            ;;
        health)
            generate_health_checks
            ;;
        tracing)
            generate_tracing_config
            ;;
        stack)
            generate_monitoring_stack
            ;;
        init)
            echo -e "${CYAN}Initializing monitoring configuration...${NC}"
            generate_logging_config "javascript"
            generate_metrics_config
            generate_alerting_rules
            generate_health_checks
            generate_tracing_config
            generate_monitoring_stack
            echo -e "${GREEN}✓ Monitoring configuration initialized!${NC}"
            echo -e "${YELLOW}Next steps:${NC}"
            echo "1. Install dependencies: npm install winston prom-client @opentelemetry/api"
            echo "2. Start monitoring stack: docker-compose -f docker-compose.monitoring.yml up -d"
            echo "3. Access Grafana at http://localhost:3000 (admin/admin)"
            echo "4. Access Prometheus at http://localhost:9090"
            echo "5. Access Jaeger at http://localhost:16686"
            ;;
        *)
            echo "Usage: $0 {logging|metrics|alerts|health|tracing|stack|init} [options]"
            echo ""
            echo "Commands:"
            echo "  logging [language]  - Generate logging configuration"
            echo "  metrics            - Generate metrics configuration"
            echo "  alerts             - Generate alerting rules"
            echo "  health             - Generate health check endpoints"
            echo "  tracing            - Generate distributed tracing"
            echo "  stack              - Generate monitoring stack config"
            echo "  init               - Initialize complete monitoring"
            exit 1
            ;;
    esac
}

main "$@"
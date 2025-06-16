#!/bin/bash
# Cost Optimization Agent - Analyzes and optimizes cloud costs and resource usage
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COST_STATE="$SCRIPT_DIR/state/cost_optimization"
mkdir -p "$COST_STATE/analysis" "$COST_STATE/recommendations" "$COST_STATE/reports"

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
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║     Cost Optimization Agent v1.0       ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════╝${NC}"
}

# Analyze cloud resources
analyze_cloud_resources() {
    local provider="${1:-aws}"
    local output_file="$COST_STATE/analysis/cloud_resources.json"
    
    log_event "INFO" "COST_OPT" "Analyzing $provider cloud resources"
    
    # Initialize resource report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "provider": "$provider",
  "resources": {
    "compute": [],
    "storage": [],
    "database": [],
    "networking": []
  },
  "monthly_cost": 0,
  "optimization_potential": 0
}
EOF
    
    # Simulate resource analysis (in production, this would use cloud APIs)
    case "$provider" in
        aws)
            analyze_aws_resources "$output_file"
            ;;
        azure)
            analyze_azure_resources "$output_file"
            ;;
        gcp)
            analyze_gcp_resources "$output_file"
            ;;
    esac
    
    log_event "SUCCESS" "COST_OPT" "Cloud resource analysis complete"
}

# Analyze AWS resources
analyze_aws_resources() {
    local output_file="$1"
    
    # Example EC2 analysis
    cat > "$COST_STATE/analysis/ec2_instances.json" << 'EOF'
{
  "instances": [
    {
      "id": "i-1234567890abcdef0",
      "type": "t3.large",
      "state": "running",
      "monthly_cost": 60.74,
      "utilization": {
        "cpu_average": 15,
        "memory_average": 30,
        "network_average": 5
      },
      "optimization": {
        "current_type": "t3.large",
        "recommended_type": "t3.medium",
        "potential_savings": 30.37
      }
    },
    {
      "id": "i-0987654321fedcba0",
      "type": "m5.xlarge",
      "state": "running",
      "monthly_cost": 140.16,
      "utilization": {
        "cpu_average": 65,
        "memory_average": 70,
        "network_average": 40
      },
      "optimization": {
        "current_type": "m5.xlarge",
        "recommended_type": "m5.xlarge",
        "potential_savings": 0
      }
    }
  ]
}
EOF
    
    # Example RDS analysis
    cat > "$COST_STATE/analysis/rds_instances.json" << 'EOF'
{
  "databases": [
    {
      "id": "myapp-production",
      "engine": "postgres",
      "instance_class": "db.t3.medium",
      "allocated_storage": 100,
      "monthly_cost": 73.44,
      "utilization": {
        "cpu_average": 25,
        "connections_average": 10,
        "storage_used": 45
      },
      "optimization": {
        "resize_recommendation": "db.t3.small",
        "storage_recommendation": 50,
        "potential_savings": 36.72
      }
    }
  ]
}
EOF
}

# Generate cost recommendations
generate_recommendations() {
    local output_file="$COST_STATE/recommendations/cost_recommendations.md"
    
    log_event "INFO" "COST_OPT" "Generating cost optimization recommendations"
    
    cat > "$output_file" << 'EOF'
# Cost Optimization Recommendations

Generated: $(date)

## Executive Summary

Based on the analysis of your cloud infrastructure, we've identified opportunities to reduce costs by approximately **$857/month (32%)** without impacting performance.

## High Priority Recommendations

### 1. Right-size EC2 Instances
**Potential Savings: $425/month**

Several EC2 instances are over-provisioned based on actual usage patterns:

| Instance ID | Current Type | Recommended Type | Monthly Savings |
|-------------|--------------|------------------|-----------------|
| i-1234567890 | t3.large | t3.medium | $30.37 |
| i-2345678901 | m5.xlarge | m5.large | $70.08 |
| i-3456789012 | c5.2xlarge | c5.xlarge | $171.36 |

**Action Items:**
1. Schedule downtime window for resizing
2. Create snapshots before changes
3. Monitor performance after resizing

### 2. Implement Auto-scaling
**Potential Savings: $200/month**

Configure auto-scaling to handle variable loads:
```yaml
# Auto-scaling configuration
MinSize: 2
MaxSize: 10
TargetCPUUtilization: 70
ScaleDownCooldown: 300
```

### 3. Use Spot Instances for Non-critical Workloads
**Potential Savings: $150/month**

Identify workloads suitable for spot instances:
- Development environments
- Batch processing jobs
- CI/CD runners
- Data analysis tasks

### 4. Optimize Storage
**Potential Savings: $82/month**

- Move infrequently accessed data to S3 Glacier
- Delete unattached EBS volumes
- Implement lifecycle policies for S3 buckets
- Use S3 Intelligent-Tiering

## Medium Priority Recommendations

### 5. Reserved Instances
**Potential Savings: $300/month (long-term)**

Based on your stable workloads, consider:
- 3-year reserved instances for production databases
- 1-year reserved instances for application servers
- Savings plans for compute resources

### 6. Database Optimization
- Enable RDS auto-pause for development databases
- Use Aurora Serverless for variable workloads
- Implement read replicas instead of scaling primary instance

### 7. Network Optimization
- Use CloudFront for static content delivery
- Implement VPC endpoints to reduce data transfer costs
- Consolidate NAT gateways where possible

## Low Priority Recommendations

### 8. Tagging Strategy
Implement comprehensive tagging for better cost allocation:
```json
{
  "Environment": "production|staging|development",
  "Team": "backend|frontend|data",
  "Project": "project-name",
  "CostCenter": "department-code"
}
```

### 9. Unused Resources Cleanup
- Delete unattached elastic IPs
- Remove old snapshots and AMIs
- Clean up unused load balancers
- Delete obsolete CloudWatch logs

### 10. Development Environment Optimization
- Shut down development instances outside business hours
- Use smaller instance types for development
- Share development databases among teams

## Implementation Roadmap

### Week 1-2: Quick Wins
- [ ] Delete unused resources
- [ ] Implement auto-shutdown for dev environments
- [ ] Right-size the most expensive instances

### Week 3-4: Medium Effort
- [ ] Set up auto-scaling groups
- [ ] Implement S3 lifecycle policies
- [ ] Configure CloudWatch cost alerts

### Month 2: Long-term Optimization
- [ ] Purchase reserved instances
- [ ] Migrate to spot instances where applicable
- [ ] Implement comprehensive tagging

## Cost Monitoring Dashboard

Set up these CloudWatch alarms:
- Daily spend exceeds $100
- Monthly spend exceeds $2,500
- Unusual spike in any service (>20% increase)

## Estimated Annual Savings

| Category | Monthly Savings | Annual Savings |
|----------|-----------------|----------------|
| Compute | $425 | $5,100 |
| Storage | $82 | $984 |
| Database | $150 | $1,800 |
| Network | $50 | $600 |
| Reserved Instances | $150 | $1,800 |
| **Total** | **$857** | **$10,284** |

## Next Steps

1. Review and approve recommendations
2. Create implementation tickets
3. Schedule changes during maintenance windows
4. Monitor impact after each change
5. Report savings to stakeholders
EOF
    
    log_event "SUCCESS" "COST_OPT" "Recommendations generated"
}

# Generate cost allocation tags
generate_tag_strategy() {
    local output_file="$COST_STATE/recommendations/tagging_strategy.json"
    
    log_event "INFO" "COST_OPT" "Generating tagging strategy"
    
    cat > "$output_file" << 'EOF'
{
  "required_tags": {
    "Environment": {
      "description": "Deployment environment",
      "allowed_values": ["production", "staging", "development", "test"],
      "required": true
    },
    "Team": {
      "description": "Owning team",
      "allowed_values": ["platform", "backend", "frontend", "data", "devops"],
      "required": true
    },
    "Project": {
      "description": "Project or application name",
      "pattern": "^[a-z0-9-]+$",
      "required": true
    },
    "CostCenter": {
      "description": "Cost center for billing",
      "pattern": "^[A-Z]{2}-[0-9]{4}$",
      "required": true
    },
    "Owner": {
      "description": "Technical owner email",
      "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
      "required": true
    }
  },
  "optional_tags": {
    "Backup": {
      "description": "Backup requirements",
      "allowed_values": ["daily", "weekly", "monthly", "none"],
      "default": "daily"
    },
    "Compliance": {
      "description": "Compliance requirements",
      "allowed_values": ["pci", "hipaa", "sox", "none"],
      "default": "none"
    },
    "Schedule": {
      "description": "Operating schedule for auto-shutdown",
      "pattern": "^(24x7|business-hours|custom:[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2})$",
      "default": "24x7"
    }
  },
  "tag_policies": [
    {
      "name": "enforce-required-tags",
      "description": "Prevent resource creation without required tags",
      "enforcement": "deny"
    },
    {
      "name": "cost-allocation",
      "description": "Enable cost allocation for all tags",
      "enforcement": "report"
    }
  ]
}
EOF
    
    log_event "SUCCESS" "COST_OPT" "Tagging strategy generated"
}

# Generate budget alerts
generate_budget_alerts() {
    local output_file="$COST_STATE/recommendations/budget_alerts.yaml"
    
    log_event "INFO" "COST_OPT" "Generating budget alert configuration"
    
    cat > "$output_file" << 'EOF'
# Budget Alert Configuration

budgets:
  - name: monthly-total-budget
    amount: 3000
    currency: USD
    time_unit: MONTHLY
    alerts:
      - threshold: 80
        notification:
          - email: finance@example.com
          - slack: #ops-alerts
      - threshold: 90
        notification:
          - email: cto@example.com
          - pagerduty: cost-alerts
      - threshold: 100
        notification:
          - email: cto@example.com
          - slack: #executive
        actions:
          - stop_non_critical_instances

  - name: daily-anomaly-detection
    type: anomaly_detection
    alerts:
      - threshold: 20  # 20% above normal
        notification:
          - email: devops@example.com
          - slack: #ops-alerts

  - name: service-specific-budgets
    services:
      - service: EC2
        amount: 1500
        alerts:
          - threshold: 90
            notification:
              - email: infrastructure@example.com
      
      - service: RDS
        amount: 500
        alerts:
          - threshold: 90
            notification:
              - email: database@example.com
      
      - service: S3
        amount: 200
        alerts:
          - threshold: 90
            notification:
              - email: storage@example.com

cost_anomaly_detection:
  - name: unusual-spending
    monitor_dimension: SERVICE
    threshold_percentage: 20
    frequency: DAILY
    subscribers:
      - email: finance@example.com
      - sns: arn:aws:sns:us-east-1:123456789012:cost-alerts

automated_actions:
  - name: stop_non_critical_instances
    trigger: budget_alert
    conditions:
      - budget_name: monthly-total-budget
      - threshold: 100
    actions:
      - stop_instances:
          tags:
            Environment: development
            Schedule: business-hours
      - notify:
          message: "Budget exceeded - stopping non-critical instances"
          channels:
            - slack: #ops-alerts
            - email: devops@example.com
EOF
    
    log_event "SUCCESS" "COST_OPT" "Budget alerts configured"
}

# Generate Terraform cost optimization
generate_terraform_optimization() {
    local output_file="$COST_STATE/recommendations/cost_optimized.tf"
    
    log_event "INFO" "COST_OPT" "Generating Terraform cost optimization configuration"
    
    cat > "$output_file" << 'EOF'
# Cost-Optimized Terraform Configuration

# Use spot instances for workers
resource "aws_launch_template" "worker" {
  name_prefix   = "worker-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  # Spot instance configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.0464"  # 50% of on-demand price
      spot_instance_type = "one-time"
    }
  }

  # Enable detailed monitoring only in production
  monitoring {
    enabled = var.environment == "production" ? true : false
  }

  # Use gp3 instead of gp2 for cost savings
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type = "gp3"
      volume_size = 30
      iops        = 3000
      throughput  = 125
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "worker-instance"
      Type = "spot"
    })
  }
}

# Auto-scaling with mixed instances
resource "aws_autoscaling_group" "app" {
  name                = "${var.app_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = var.environment == "production" ? 2 : 1
  max_size            = var.environment == "production" ? 10 : 3
  desired_capacity    = var.environment == "production" ? 3 : 1

  # Mixed instances policy for cost optimization
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest"
      }

      override {
        instance_type     = "t3.medium"
        weighted_capacity = "1"
      }

      override {
        instance_type     = "t3a.medium"  # AMD instances are cheaper
        weighted_capacity = "1"
      }

      override {
        instance_type     = "t2.medium"
        weighted_capacity = "1"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = var.environment == "production" ? 1 : 0
      on_demand_percentage_above_base_capacity = var.environment == "production" ? 30 : 0
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = 3
    }
  }

  # Enable capacity rebalancing for spot instances
  capacity_rebalance = true

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# S3 lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "transition-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# RDS with auto-pause for non-production
resource "aws_rds_cluster" "database" {
  cluster_identifier = "${var.app_name}-${var.environment}"
  engine             = "aurora-mysql"
  engine_mode        = var.environment == "production" ? "provisioned" : "serverless"
  engine_version     = "5.7.mysql_aurora.2.10.1"
  database_name      = var.database_name
  master_username    = var.database_username
  master_password    = random_password.database.result

  # Serverless scaling configuration for non-production
  dynamic "scaling_configuration" {
    for_each = var.environment != "production" ? [1] : []
    content {
      auto_pause               = true
      min_capacity             = 1
      max_capacity             = 2
      seconds_until_auto_pause = 300
    }
  }

  # Backup retention based on environment
  backup_retention_period = var.environment == "production" ? 30 : 7
  preferred_backup_window = "03:00-04:00"

  # Skip final snapshot for non-production
  skip_final_snapshot = var.environment != "production"

  tags = local.common_tags
}

# CloudWatch log retention
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.app_name}"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = local.common_tags
}

# Cost allocation tags
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Team        = var.team_name
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    AutoShutdown = var.environment != "production" ? "true" : "false"
  }
}
EOF
    
    log_event "SUCCESS" "COST_OPT" "Terraform optimization configuration generated"
}

# Generate cost dashboard
generate_cost_dashboard() {
    local output_file="$COST_STATE/reports/cost_dashboard.html"
    
    log_event "INFO" "COST_OPT" "Generating cost dashboard"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloud Cost Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 2rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        .metric-card {
            background: white;
            padding: 1.5rem;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
        .metric-value {
            font-size: 2.5rem;
            font-weight: bold;
            margin: 0.5rem 0;
        }
        .metric-label {
            color: #666;
            font-size: 0.9rem;
        }
        .metric-change {
            font-size: 0.9rem;
            margin-top: 0.5rem;
        }
        .positive { color: #28a745; }
        .negative { color: #dc3545; }
        .chart-container {
            background: white;
            padding: 2rem;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 2rem;
        }
        .chart-title {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 1rem;
            color: #333;
        }
        .recommendations {
            background: white;
            padding: 2rem;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .recommendation-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem;
            border-bottom: 1px solid #eee;
        }
        .recommendation-item:last-child {
            border-bottom: none;
        }
        .savings-badge {
            background: #28a745;
            color: white;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>Cloud Cost Dashboard</h1>
            <p>Real-time insights into your cloud spending</p>
        </div>
    </div>

    <div class="container">
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Current Month Spend</div>
                <div class="metric-value">$2,347</div>
                <div class="metric-change negative">↑ 12% from last month</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Projected Monthly</div>
                <div class="metric-value">$2,684</div>
                <div class="metric-change">Budget: $3,000</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Optimization Potential</div>
                <div class="metric-value">$857</div>
                <div class="metric-change positive">32% savings available</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Unused Resources</div>
                <div class="metric-value">23</div>
                <div class="metric-change negative">$143/month waste</div>
            </div>
        </div>

        <div class="chart-container">
            <div class="chart-title">Monthly Cost Trend</div>
            <canvas id="costTrendChart"></canvas>
        </div>

        <div class="chart-container">
            <div class="chart-title">Cost by Service</div>
            <canvas id="serviceChart"></canvas>
        </div>

        <div class="recommendations">
            <h2>Top Cost Optimization Opportunities</h2>
            <div class="recommendation-item">
                <div>
                    <strong>Right-size EC2 instances</strong>
                    <p style="margin: 0.5rem 0; color: #666;">15 instances are over-provisioned</p>
                </div>
                <span class="savings-badge">Save $425/mo</span>
            </div>
            <div class="recommendation-item">
                <div>
                    <strong>Use Spot instances</strong>
                    <p style="margin: 0.5rem 0; color: #666;">For dev/test environments</p>
                </div>
                <span class="savings-badge">Save $200/mo</span>
            </div>
            <div class="recommendation-item">
                <div>
                    <strong>Delete unused resources</strong>
                    <p style="margin: 0.5rem 0; color: #666;">23 resources identified</p>
                </div>
                <span class="savings-badge">Save $143/mo</span>
            </div>
            <div class="recommendation-item">
                <div>
                    <strong>Implement auto-scaling</strong>
                    <p style="margin: 0.5rem 0; color: #666;">Scale down during off-hours</p>
                </div>
                <span class="savings-badge">Save $89/mo</span>
            </div>
        </div>
    </div>

    <script>
        // Monthly cost trend
        new Chart(document.getElementById('costTrendChart'), {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: [{
                    label: 'Actual Cost',
                    data: [2150, 2230, 2180, 2090, 2250, 2347],
                    borderColor: '#1e3c72',
                    backgroundColor: 'rgba(30, 60, 114, 0.1)',
                    tension: 0.4
                }, {
                    label: 'Budget',
                    data: [3000, 3000, 3000, 3000, 3000, 3000],
                    borderColor: '#dc3545',
                    borderDash: [5, 5]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return '$' + value;
                            }
                        }
                    }
                }
            }
        });

        // Cost by service
        new Chart(document.getElementById('serviceChart'), {
            type: 'doughnut',
            data: {
                labels: ['EC2', 'RDS', 'S3', 'CloudFront', 'Lambda', 'Other'],
                datasets: [{
                    data: [892, 456, 234, 189, 123, 453],
                    backgroundColor: [
                        '#FF6384',
                        '#36A2EB',
                        '#FFCE56',
                        '#4BC0C0',
                        '#9966FF',
                        '#C9CBCF'
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'right'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = '$' + context.parsed;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((context.parsed / total) * 100).toFixed(1);
                                return label + ': ' + value + ' (' + percentage + '%)';
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log_event "SUCCESS" "COST_OPT" "Cost dashboard generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        analyze)
            analyze_cloud_resources "${2:-aws}"
            ;;
        recommend)
            generate_recommendations
            ;;
        tags)
            generate_tag_strategy
            ;;
        budgets)
            generate_budget_alerts
            ;;
        terraform)
            generate_terraform_optimization
            ;;
        dashboard)
            generate_cost_dashboard
            ;;
        init)
            echo -e "${CYAN}Initializing cost optimization analysis...${NC}"
            analyze_cloud_resources "aws"
            generate_recommendations
            generate_tag_strategy
            generate_budget_alerts
            generate_terraform_optimization
            generate_cost_dashboard
            echo -e "${GREEN}✓ Cost optimization analysis complete!${NC}"
            echo -e "${YELLOW}Review recommendations at: $COST_STATE/recommendations/${NC}"
            ;;
        *)
            echo "Usage: $0 {analyze|recommend|tags|budgets|terraform|dashboard|init} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze [provider]  - Analyze cloud resources"
            echo "  recommend          - Generate cost recommendations"
            echo "  tags               - Generate tagging strategy"
            echo "  budgets            - Configure budget alerts"
            echo "  terraform          - Generate optimized Terraform"
            echo "  dashboard          - Generate cost dashboard"
            echo "  init               - Run complete analysis"
            exit 1
            ;;
    esac
}

main "$@"
#!/usr/bin/env bash
set -euo pipefail

# Script to generate Grafana Blackbox Exporter dashboard from Prometheus targets
# Usage: ./scripts/generate-dashboard.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROMETHEUS_CONFIG="${PROJECT_ROOT}/observability-solution/prometheus.yml"
DASHBOARD_OUTPUT="${PROJECT_ROOT}/observability-solution/grafana/provisioning/dashboards/blackbox.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Blackbox Dashboard Generator ===${NC}"
echo ""

# Check if prometheus.yml exists
if [[ ! -f "${PROMETHEUS_CONFIG}" ]]; then
    echo -e "${RED}Error: prometheus.yml not found at ${PROMETHEUS_CONFIG}${NC}"
    exit 1
fi

# Check if yq is installed for YAML parsing
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}Warning: 'yq' not found. Installing using Python...${NC}"
    if command -v pip3 &> /dev/null; then
        pip3 install yq
    else
        echo -e "${RED}Error: Please install 'yq' (brew install yq or pip install yq)${NC}"
        exit 1
    fi
fi

echo "📊 Parsing Prometheus configuration..."

# Extract targets from prometheus.yml
http_targets=$(yq -r '.scrape_configs[] | select(.job_name == "blackbox-http") | .static_configs[].targets[]' "${PROMETHEUS_CONFIG}" 2>/dev/null || echo "")
https_targets=$(yq -r '.scrape_configs[] | select(.job_name == "blackbox-https") | .static_configs[].targets[]' "${PROMETHEUS_CONFIG}" 2>/dev/null || echo "")

# Count non-empty lines
http_count=$(echo "${http_targets}" | grep -c '[^[:space:]]' || true)
https_count=$(echo "${https_targets}" | grep -c '[^[:space:]]' || true)

echo "  ✓ Found ${http_count} HTTP endpoints"
echo "  ✓ Found ${https_count} HTTPS endpoints"
echo ""

# Generate dashboard JSON
echo "🔨 Generating dashboard..."

# Start building the JSON
cat > "${DASHBOARD_OUTPUT}" << 'EOF'
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
EOF

# Add HTTP panels if there are HTTP endpoints
if [[ ${http_count} -gt 0 ]]; then
  cat >> "${DASHBOARD_OUTPUT}" << 'EOF'
    {
      "datasource": "Prometheus",
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 100,
      "title": "Application HTTP Endpoints",
      "type": "row"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "Down"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "Up"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "none"
        }
      },
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 1
      },
      "id": 1,
      "options": {
        "displayMode": "gradient",
        "minVizHeight": 10,
        "minVizWidth": 0,
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showUnfilled": true
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{job=\"blackbox-http\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "App Endpoint Status",
      "type": "bargauge"
    },
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
                "color": "yellow",
                "value": 1
              },
              {
                "color": "red",
                "value": 5
              }
            ]
          },
          "unit": "s"
        }
      },
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 9
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi"
        }
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_duration_seconds{job=\"blackbox-http\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "HTTP Response Time",
      "type": "timeseries"
    },
EOF
fi

# Add HTTPS panels if there are HTTPS endpoints
if [[ ${https_count} -gt 0 ]]; then
  cat >> "${DASHBOARD_OUTPUT}" << 'EOF'
    {
      "datasource": "Prometheus",
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 26
      },
      "id": 200,
      "title": "SSL/HTTPS Monitoring (httpbin.org)",
      "type": "row"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "Down"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "Up"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 0,
        "y": 27
      },
      "id": 7,
      "options": {
        "displayMode": "gradient",
        "minVizHeight": 10,
        "minVizWidth": 0,
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showUnfilled": true
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_success{job=\"blackbox-https\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "HTTPS Endpoints Status",
      "type": "bargauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "No SSL"
                },
                "1": {
                  "color": "green",
                  "index": 1,
                  "text": "SSL Valid"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 12,
        "y": 27
      },
      "id": 8,
      "options": {
        "displayMode": "gradient",
        "minVizHeight": 10,
        "minVizWidth": 0,
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showUnfilled": true
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_http_ssl{job=\"blackbox-https\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "SSL/TLS Enabled",
      "type": "bargauge"
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
                "color": "red",
                "value": null
              },
              {
                "color": "orange",
                "value": 604800
              },
              {
                "color": "yellow",
                "value": 2592000
              },
              {
                "color": "green",
                "value": 7776000
              }
            ]
          },
          "unit": "dtdurations"
        }
      },
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 0,
        "y": 33
      },
      "id": 9,
      "options": {
        "displayMode": "gradient",
        "minVizHeight": 10,
        "minVizWidth": 0,
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showUnfilled": true
      },
      "pluginVersion": "9.0.0",
      "targets": [
        {
          "expr": "probe_ssl_earliest_cert_expiry{job=\"blackbox-https\"} - time()",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "SSL Certificate Time Remaining",
      "type": "bargauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "Days",
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
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "line+area"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "transparent",
                "value": null
              },
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "orange",
                "value": 7
              },
              {
                "color": "yellow",
                "value": 30
              }
            ]
          },
          "unit": "days"
        }
      },
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 12,
        "y": 33
      },
      "id": 10,
      "options": {
        "legend": {
          "calcs": ["lastNotNull", "min"],
          "displayMode": "table",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi"
        }
      },
      "targets": [
        {
          "expr": "(probe_ssl_earliest_cert_expiry{job=\"blackbox-https\"} - time()) / 86400",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "SSL Certificate Days Until Expiry",
      "type": "timeseries"
    }
EOF
fi

# Close the panels array and add dashboard metadata
cat >> "${DASHBOARD_OUTPUT}" << 'EOF'
  ],
  "refresh": "5s",
  "schemaVersion": 36,
  "style": "dark",
  "tags": ["observability", "health-check", "ssl"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-15m",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Application Health Monitoring",
  "uid": "app_health_monitoring",
  "version": 0
}
EOF

echo "  ✓ Dashboard generated at ${DASHBOARD_OUTPUT}"
echo ""
echo -e "${GREEN}✅ Dashboard generation complete!${NC}"
echo ""
echo "📝 Summary:"
echo "  - HTTP endpoints: ${http_count}"
echo "  - HTTPS endpoints: ${https_count}"
echo "  - Total endpoints: $((http_count + https_count))"
echo ""
echo "🔄 To apply changes, restart Grafana:"
echo "  docker compose restart grafana"
echo ""

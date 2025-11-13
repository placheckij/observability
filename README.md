# Observability Solution

A production-ready observability stack using Prometheus, Grafana, Blackbox Exporter, and Alertmanager. Monitor HTTP/HTTPS endpoints, track SSL certificate expiration, and receive alerts when services go down. Includes a demo FastAPI application for testing, or use just the monitoring components in your own projects.

[![GitHub](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://raw.githubusercontent.com/placheckij/observability/main/LICENSE)
[![Build and Test](https://github.com/placheckij/observability/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/placheckij/observability/actions/workflows/build-and-test.yml)

> ⭐ If you find this project useful, please consider giving it a star! It helps others discover it and motivates further development.

## Table of Contents
- [Project Structure](#project-structure)
- [Usage](#usage)
  - [Option 1: Test Run with Demo Application](#option-1-test-run-with-demo-application)
  - [Option 2: Use Observability Solution in Your Own Project](#option-2-use-observability-solution-in-your-own-project)
- [Testing the Alert System](#testing-the-alert-system)
- [Remarks](#remarks)
- [Support & Contact](#support--contact)
- [License](#license)

## Project Structure
```
observability/
├── .github/
│   ├── CODEOWNERS                  # Code review assignments
│   └── workflows/
│       └── build-and-test.yml      # CI/CD pipeline
├── docker-compose.yml              # Orchestrates all services
├── scripts/
│   └── generate-dashboard.sh       # Auto-generates Grafana dashboards
├── observability-solution/         # Monitoring & observability configs
│   ├── prometheus.yml              # Prometheus configuration
│   ├── alertmanager.yml            # Alertmanager configuration
│   ├── blackbox.yml                # Blackbox Exporter configuration
│   ├── rules/
│   │   └── alerts.yml              # Prometheus alerting rules
│   └── grafana/
│       └── provisioning/
│           ├── datasources/        # Auto-configured datasources
│           │   └── prometheus-data-source.yml
│           └── dashboards/         # Dashboard definitions
│               ├── default.yml     # Dashboard provider config
│               └── blackbox.json   # Endpoint monitoring dashboard
└── observability-test-app/         # Test application to monitor
    ├── Dockerfile                  # Multi-stage build (CIS/OWASP compliant)
    ├── pyproject.toml              # Python dependencies
    ├── main.py                     # FastAPI application
    ├── utils.py                    # Utility functions
    ├── api/                        # API endpoints (v1, v2)
    │   ├── __init__.py
    │   ├── deps.py
    │   ├── api_v1/
    │   │   └── endpoints/
    │   └── api_v2/
    │       └── endpoints/
    └── core/                       # Core configuration
        ├── __init__.py
        ├── config.py
        └── logging_setup.json
```

# Usage

## Option 1: Test Run with Demo Application

Use this option to test the complete observability solution with the included demo app.

1.	Clone or download the entire repository

2.	**Configure secrets** (IMPORTANT for production):
    ```bash
    cp .env.example .env
    # Edit .env and set a strong GRAFANA_ADMIN_PASSWORD
    ```

3.	Update configuration (optional):

    •	Alertmanager webhook/SMTP configs in `observability-solution/alertmanager.yml` ([docs](https://prometheus.io/docs/alerting/latest/configuration/))

4.	Run `docker compose up -d --build`
5.	Access the services:

    •	**Demo App**: http://localhost:3001/health

    •	**Grafana**: http://localhost:9001 (credentials: admin / your_password_from_.env)

    •	**Prometheus**: http://localhost:9090

    •	**Alertmanager**: http://localhost:9093

6.	In Grafana:

    •	Data sources are auto-configured from `observability-solution/grafana/provisioning/datasources/` ([docs](https://grafana.com/docs/grafana/latest/administration/provisioning/#example-data-source-configuration-file))

    •	Dashboards are auto-loaded from `observability-solution/grafana/provisioning/dashboards/` ([docs](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards))

7.	Test alerts by stopping the app: `docker stop observability-app`
8.	Clean up: `docker compose down -v` (the `-v` flag removes volumes, resetting any manual changes to dashboards/datasources)

## Option 2: Use Observability Solution in Your Own Project

Use this option to integrate the monitoring stack into your existing application.

1.	Copy the `observability-solution/` directory to your project:
    ```bash
    cp -r observability-solution/ /path/to/your/project/
    ```

2.	Add the monitoring services to your existing `docker-compose.yml`:
    ```yaml
    services:
      # Your existing services here...
      
      prometheus:
        image: prom/prometheus:latest
        volumes:
          - ./observability-solution/prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - ./observability-solution/rules:/etc/prometheus/rules:ro
        command:
          - "--config.file=/etc/prometheus/prometheus.yml"
        ports:
          - "9090:9090"
        networks:
          - monitoring

      blackbox:
        image: prom/blackbox-exporter:latest
        volumes:
          - ./observability-solution/blackbox.yml:/etc/blackbox_exporter/config.yml:ro
        command:
          - "--config.file=/etc/blackbox_exporter/config.yml"
        ports:
          - "9115:9115"
        networks:
          - monitoring

      alertmanager:
        image: prom/alertmanager:latest
        volumes:
          - ./observability-solution/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
        command:
          - "--config.file=/etc/alertmanager/alertmanager.yml"
        ports:
          - "9093:9093"
        networks:
          - monitoring

      grafana:
        image: grafana/grafana-oss:latest
        environment:
          - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
        volumes:
          - grafana-data:/var/lib/grafana
          - ./observability-solution/grafana/provisioning:/etc/grafana/provisioning:ro
        ports:
          - "9001:3000"
        networks:
          - monitoring

    volumes:
      grafana-data:

    networks:
      monitoring:
        driver: bridge
    ```

3.	Update `observability-solution/prometheus.yml` to monitor your application endpoints:
    ```yaml
    scrape_configs:
      - job_name: 'blackbox-http'
        metrics_path: /probe
        params:
          module: [http_2xx]
        static_configs:
          - targets:
            - http://your-app:8080/health        # Replace with your endpoints
            - http://your-app:8080/api/status
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: blackbox:9115
    ```

4.	**Generate Grafana dashboards** automatically from your Prometheus configuration:
    ```bash
    # Copy the dashboard generation script
    cp scripts/generate-dashboard.sh /path/to/your/project/scripts/
    chmod +x /path/to/your/project/scripts/generate-dashboard.sh
    
    # Generate dashboards based on your prometheus.yml endpoints
    ./scripts/generate-dashboard.sh
    ```
    
    The script will:
    - Parse your `prometheus.yml` configuration
    - Detect HTTP and HTTPS endpoints
    - Generate a complete Grafana dashboard with endpoint monitoring panels
    - Include SSL/TLS monitoring panels for HTTPS endpoints (certificate expiry, SSL status, etc.)
    - Save the dashboard to `observability-solution/grafana/provisioning/dashboards/blackbox.json`
    
    > **Note:** Run this script whenever you add or remove endpoints in `prometheus.yml` to keep dashboards in sync.

5.	Ensure your application is on the same Docker network (`monitoring`)

6.	Configure alerting in `observability-solution/alertmanager.yml` with your notification channels ([docs](https://prometheus.io/docs/alerting/latest/configuration/))

7.	Run `docker compose up -d`

## Testing the Alert System

The observability solution includes a pre-configured alerting system with Alertmanager. Here's how to test it:

### View Alert Rules and Status

Check all alert rules (shows both firing and inactive alerts):
```bash
curl http://localhost:9090/api/v1/rules | jq
```

Check active/firing alerts (empty when everything is healthy):
```bash
curl http://localhost:9090/api/v1/alerts | jq
```

Check Alertmanager (shows alerts sent to Alertmanager):
```bash
curl http://localhost:9093/api/v2/alerts | jq
```

**Note**: An empty alerts list means no alerts are firing - this is good! It means all services are healthy.

### Trigger a Test Alert

**Option 1: Stop the demo app** (triggers `EndpointDown` alert after 2 minutes)
```bash
docker stop observability-app
```

Wait 2-3 minutes, then check the app logs to see the alert webhook:
```bash
docker logs observability-app
```

Start the app again:
```bash
docker start observability-app
```

**Option 2: View alert rules in Prometheus**

Visit http://localhost:9090/alerts to see all configured alert rules and their current status.

### Configured Alerts

The solution includes these example alerts:

- **EndpointDown** (critical): HTTP endpoint unreachable for >2 minutes
- **EndpointSlow** (warning): Response time >5 seconds for >5 minutes  
- **HighHTTPErrorRate** (warning): Non-2xx status codes detected
- **SSLCertificateExpiringSoon** (critical): SSL cert expires in <7 days
- **SSLCertificateExpiringIn30Days** (warning): SSL cert expires in <30 days
- **BlackboxExporterDown** (critical): Monitoring system failure

### Webhook Endpoints

The demo app includes webhook endpoints that log received alerts:
- `POST /api/alerts` - Default alert receiver (logs to app)
- `POST /api/alerts/critical` - Critical alerts only

Check webhook logs:
```bash
docker logs observability-app -f | grep "ALERT"
```

### Customize Alertmanager

Edit `observability-solution/alertmanager.yml` to configure your notification channels:
- Slack webhooks
- Email (SMTP)
- PagerDuty
- Custom webhooks

See the [Alertmanager documentation](https://prometheus.io/docs/alerting/latest/configuration/) for all options.

## Remarks
1.	Optionally add a small Python probe for complex JSON checks and expose /metrics for Prometheus.
2.  If you want to start from scratch, go for `docker compose down -v` (`-v` is necessary to also delete volumes - otherwise any changes made to dashboards / datasources will be persisted in the mounted config files).

## Support & Contact

If you need assistance, have questions, or want to report issues:

- **GitHub Discussions**: [Join the discussion](https://github.com/placheckij/observability/discussions) - Ask questions, share ideas, or discuss implementation
- **GitHub Issues**: [Report bugs or request features](https://github.com/placheckij/observability/issues)
- **Email**: [jakub@plachecki.dev](mailto:jakub@plachecki.dev)
- **LinkedIn**: [Connect with me](https://www.linkedin.com/in/jakubplachecki)

Contributions, feedback, and suggestions are welcome!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Components

This project incorporates the following open-source components:

**Observability Stack:**
- [Prometheus](https://prometheus.io/) - Apache License 2.0
- [Grafana OSS](https://grafana.com/) - AGPL-3.0
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) - Apache License 2.0
- [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter) - Apache License 2.0

**Test Application:**
- [FastAPI](https://fastapi.tiangolo.com/) - MIT License
- [Uvicorn](https://www.uvicorn.org/) - BSD-3-Clause License
- [Pydantic](https://pydantic-docs.helpmanual.io/) - MIT License

All third-party components are used in accordance with their respective licenses.

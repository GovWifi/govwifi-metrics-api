# Metrics API

A Ruby/Sinatra-based REST API for internal services to POST metrics data. It uses PostgreSQL as its data store.

## Features

- Provides an endpoint `POST /v1/record` expecting `{"name": "...", "value": 1.0, "datetime": "iso8601-optional"}`
- Provides an endpoint `GET /v1/data/export` to retrieve metrics as JSON, with filtering options.
- Uses Sequel as the ORM to store data in the `metrics` table.
- Composite unique index on `(name, datetime)`.
- Implements layered design (API -> Business -> Database).
- Managed via Docker Compose and configured by environment variables (12-factor approach).
- **Host Authorization**: Restricts API access to a list of permitted hosts to prevent DNS rebinding attacks.

## Configuration

The application is configured using the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_DSN` | PostgreSQL connection string | Required |
| `METRICS_API_KEY` | Shared secret for Bearer token authentication | Required |
| `PERMITTED_HOSTS` | Comma-separated list of allowed `Host` headers | `localhost` |
| `LOG_LEVEL` | Logging level (`debug`, `info`, `warn`, `error`) | `info` |

### Note on Host Authorization

If the METRICS_API_KEY is not set in the environment then not authorisation checks will be performed. This is used to aid the automated CI/CD testing.

Requests with a `Host` header not present in `PERMITTED_HOSTS` will return a `403 Forbidden`. The `/health` endpoint is exempted from this check to facilitate load balancer health checks.

## Quickstart

To build and run tests:

```bash
make test
```

To run lint checks:

```bash
make lint
```

To run the application locally:

```bash
make up
# Then POST to localhost:44567/v1/record
# e.g.: curl -X POST -H "Content-Type: application/json" -d '{"name":"test","value":"1.0"}' http://localhost:44567/v1/record
```

To seed the database with two years of mock metrics data for testing:

```bash
make seed
```

To generate a 64-character random API key for securing the API:

```bash
make generate_api_token
```

### Data Export

The endpoint `GET /v1/data/export` allows retrieving metrics in JSON format. It supports the following query parameters:

- `from`: ISO8601 start datetime (e.g., `2023-10-01T00:00:00Z`).
- `to`: ISO8601 end datetime (e.g., `2023-10-31T23:59:59Z`).
- `year`: Filter by year (requires `month`).
- `month`: Filter by month (requires `year`).

**Example usage:**

```bash
# Export all metrics for October 2023
curl -H "Authorization: Bearer your_api_key" "http://localhost:44567/v1/data/export?year=2023&month=10"

# Export metrics in a specific range
curl -H "Authorization: Bearer your_api_key" "http://localhost:44567/v1/data/export?from=2023-10-27T00:00:00Z&to=2023-10-27T23:59:59Z"
```

```

To tear down:
```bash
make down
```

## GitHub Actions

This API is set up to build and test automatically via GitHub Actions in `docker-compose`.

## License

MIT

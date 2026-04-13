# Metrics API

A Ruby/Sinatra-based REST API for internal services to POST metrics data. It uses PostgreSQL as its data store.

## Features
- Provides an endpoint `POST /v1/record` expecting `{"name": "...", "value": 1.0, "datetime": "iso8601-optional"}`
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
| `PERMITTED_HOSTS` | Comma-separated list of allowed `Host` headers | `localhost` |
| `LOG_LEVEL` | Logging level (`debug`, `info`, `warn`, `error`) | `info` |

### Note on Host Authorization
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

To tear down:
```bash
make down
```

## GitHub Actions
This API is set up to build and test automatically via GitHub Actions in `docker-compose`.

## License
MIT

# Metrics API

A Ruby/Sinatra-based REST API for internal services to POST metrics data. It uses PostgreSQL as its data store.

## Features
- Provides an endpoint `POST /v1/record` expecting `{"name": "...", "value": 1.0, "datetime": "iso8601-optional"}`
- Uses Sequel as the ORM to store data in the `metrics` table.
- Composite unique index on `(name, datetime)`.
- Implements layered design (API -> Business -> Database).
- Managed via Docker Compose and configured by environment variables (12-factor approach).

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



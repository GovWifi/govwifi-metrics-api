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

## API Reference

All requests must be made to the base URL configured for the service (locally, `http://localhost:44567`).

### Authentication & Security

#### Bearer Token Authentication
When the `METRICS_API_KEY` environment variable is set, the API enforces Bearer token authentication for `POST /v1/record` and `GET /v1/data/export`.
Include your key in the `Authorization` header of your requests:

```http
Authorization: Bearer <your_api_key>
```

#### Host Authorization
To prevent DNS rebinding attacks, all endpoints (except `/health`) validate that the incoming `Host` header is present in the `PERMITTED_HOSTS` whitelist (configured via environment variables). Unrecognized hosts will result in a `403 Forbidden` response.

---

### Endpoints

#### 1. Root Status Check
`GET /`

Check the operational status of the service itself.

##### Headers
- `Content-Type`: `application/json`

##### Response
- **Status Code**: `200 OK`
- **Body**:
  ```json
  {
    "status": "OK"
  }
  ```

---

#### 2. Health Check
`GET /health`

Verifies that the API service is up and is successfully connected to the PostgreSQL database. This endpoint is exempted from host authorization checks.

##### Headers
- `Content-Type`: `application/json`

##### Response
- **Success Response**:
  - **Status Code**: `200 OK`
  - **Body**:
    ```json
    {
      "status": "OK",
      "database": "connected"
    }
    ```
- **Error Response** (when database is down):
  - **Status Code**: `503 Service Unavailable`
  - **Body**:
    ```json
    {
      "status": "Error",
      "database": "disconnected",
      "error": "connection refused"
    }
    ```

---

#### 3. Record a Metric
`POST /v1/record`

Record a new metric data point.

##### Headers
- `Content-Type`: `application/json`
- `Authorization`: `Bearer <token>` (Required if `METRICS_API_KEY` is configured)

##### Request Body Schema
The request body must be a valid JSON object.

| Parameter | Type | Required | Default | Description & Validation Rules |
| :--- | :--- | :--- | :--- | :--- |
| `name` | String | **Yes** | *None* | Must be a non-empty string. Spaces and special characters are allowed. |
| `value` | Float / Int / Decimal / String | **Yes** | *None* | Must be filled. Can be a numeric float, integer, decimal, or a string representing a decimal (e.g. `"55.5"`, `-10`). Validation pattern: `/^-?\d+(\.\d+)?$/`. |
| `datetime` | String | *No* | Current UTC time | An ISO8601 parseable datetime string (e.g., `"2023-10-27T10:00:00Z"`). If omitted, empty, or null, the API automatically uses the current UTC timestamp. |

> [!IMPORTANT]
> **Unique Constraint**: The combination of `name` and `datetime` must be unique. Attempting to record a metric with the exact same name at the exact same timestamp will result in a database conflict and return `422 Unprocessable Entity`.

##### Example Payload

```json
{
  "name": "cpu_usage",
  "value": "55.5",
  "datetime": "2023-10-27T10:00:00Z"
}
```

##### Example cURL Command

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -d '{"name":"cpu_usage","value":"55.5","datetime":"2023-10-27T10:00:00Z"}' \
  http://localhost:44567/v1/record
```

##### Responses

- **Status Code**: `201 Created`
  - **Description**: Metric was successfully validated and saved.
  - **Body**:
    ```json
    {
      "message": "Metric recorded successfully"
    }
    ```

- **Status Code**: `400 Bad Request`
  - **Description**: The request body is not valid JSON.
  - **Body**:
    ```json
    {
      "error": "Invalid JSON request body"
    }
    ```

- **Status Code**: `401 Unauthorized`
  - **Description**: Missing or invalid Authorization header when `METRICS_API_KEY` is configured.
  - **Body**:
    ```json
    {
      "error": "Unauthorized"
    }
    ```

- **Status Code**: `422 Unprocessable Entity`
  - **Description**: Validation failed (e.g. missing required field, invalid number format) or a duplicate record constraint was violated.
  - **Body (Validation Failure)**:
    ```json
    {
      "error": "name is missing; value must be a float, an integer, a decimal, or a decimal string"
    }
    ```
  - **Body (Duplicate Constraint Violation)**:
    ```json
    {
      "error": "Metric 'cpu_usage' at '2023-10-27 10:00:00 UTC' already exists"
    }
    ```

- **Status Code**: `500 Internal Server Error`
  - **Description**: An unexpected error occurred on the server.
  - **Body**:
    ```json
    {
      "error": "Internal server error"
    }
    ```

---

#### 4. Export Metrics
`GET /v1/data/export`

Retrieve metric records. Returns a downloadable JSON file.

##### Headers
- `Content-Type`: `application/json`
- `Authorization`: `Bearer <token>` (Required if `METRICS_API_KEY` is configured)

##### Query Parameters
You can filter export results using either a date range or a specific month, and optionally filter by a specific metric name.
If no parameters are provided, **all** metrics in the database are returned.

> [!NOTE]
> Date range filtering (`from`/`to`) takes precedence over monthly filtering (`year`/`month`). The name filter (`name`) can be combined with either, or used on its own.

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `from` | String | *No* | Start ISO8601 datetime (inclusive). Example: `2023-10-27T00:00:00Z`. |
| `to` | String | *No* | End ISO8601 datetime (inclusive). Example: `2023-10-27T23:59:59Z`. |
| `year` | String / Int | *No* | Filter by year. **Requires `month`** to be provided as well (e.g., `2023`). |
| `month` | String / Int | *No* | Filter by month (1-12). **Requires `year`** to be provided as well (e.g., `10`). |
| `name` | String | *No* | Filter by metric name. Example: `cpu_usage`. |

##### Example cURL Commands

**Export all metrics without filtering:**
```bash
curl -H "Authorization: Bearer your_api_key" \
  http://localhost:44567/v1/data/export
```

**Export metrics filtered by name:**
```bash
curl -H "Authorization: Bearer your_api_key" \
  "http://localhost:44567/v1/data/export?name=cpu_usage"
```

**Export metrics within a date range:**
```bash
curl -H "Authorization: Bearer your_api_key" \
  "http://localhost:44567/v1/data/export?from=2023-10-27T00:00:00Z&to=2023-10-27T23:59:59Z"
```

**Export metrics by name within a date range:**
```bash
curl -H "Authorization: Bearer your_api_key" \
  "http://localhost:44567/v1/data/export?name=cpu_usage&from=2023-10-27T00:00:00Z&to=2023-10-27T23:59:59Z"
```

**Export metrics by month and year:**
```bash
curl -H "Authorization: Bearer your_api_key" \
  "http://localhost:44567/v1/data/export?year=2023&month=10"
```

##### Responses

- **Status Code**: `200 OK`
  - **Description**: Metrics retrieved successfully. The response triggers a file download containing the JSON array.
  - **Headers**:
    - `Content-Disposition`: `attachment; filename="2023-10-27-10-00-00-metrics-api-data-export.json"`
  - **Body**:
    ```json
    [
      {
        "id": 1,
        "datetime": "2023-10-27T10:00:00.000Z",
        "name": "cpu_usage",
        "value": 55.5
      },
      {
        "id": 2,
        "datetime": "2023-10-27T10:05:00.000Z",
        "name": "memory_usage",
        "value": 82.1
      }
    ]
    ```

- **Status Code**: `400 Bad Request`
  - **Description**: Provided query date parameters are in an invalid format.
  - **Body**:
    ```json
    {
      "error": "Invalid date format: no time information in \"invalid-date\""
    }
    ```

- **Status Code**: `401 Unauthorized`
  - **Description**: Missing or invalid Authorization header when `METRICS_API_KEY` is configured.
  - **Body**:
    ```json
    {
      "error": "Unauthorized"
    }
    ```

- **Status Code**: `500 Internal Server Error`
  - **Description**: An unexpected error occurred on the server.
  - **Body**:
    ```json
    {
      "error": "Internal server error"
    }
    ```

---


To tear down:
```bash
make down
```

## GitHub Actions

This API is set up to build and test automatically via GitHub Actions in `docker-compose`.

## License

MIT

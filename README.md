# PayLink

PayLink is a payment platform project developed as part of a university year-work project.

## Project Overview

The goal of PayLink is to build a platform for managing payment operations and related services.

## Development Workflow

- `main`: Stable branch.
- `develop`: Integration branch.
- `feature/*`: Branches for individual tasks.

All changes must be submitted through Pull Requests and reviewed before merging.

## DevOps Setup

### Prerequisites

- Git
- Docker Engine with the Docker Compose plugin
- Java 27 for running Maven commands locally

### Environment configuration

Copy `.env.example` to `.env` and set local PostgreSQL values in `.env`. Keep `.env` private; it is ignored by Git.
The example values are placeholders for local development only.

### Run the stack

```sh
docker compose up --build -d
docker compose ps
curl --fail http://localhost:8080/actuator/health
```

Wait until both `paylink-db` and `paylink-api` report `healthy`. The API waits for the PostgreSQL health
check before starting. Its health check calls `/actuator/health`.

Stop the services while keeping the named database volume:

```sh
docker compose down
```

### Build, tests, and lint

Use the Maven wrapper from the repository root:

```sh
./mvnw -B clean verify
```

`verify` builds the application, runs the tests, and runs Checkstyle. To run only tests or lint, use:

```sh
./mvnw -B test
./mvnw -B checkstyle:check
```

On Windows, use `mvnw.cmd` in place of `./mvnw`.

### Continuous integration

GitHub Actions runs the Maven wrapper on pushes to `main`, `develop`, and `feature/**`, and on pull requests
targeting `main` or `develop`. Pushing the `phase-1` tag also starts the workflow. CI uses Java 27 and
`./mvnw -B clean verify`, so build, tests, and Checkstyle must all pass.

## Team

Developed collaboratively as part of the PayLink year-work project.

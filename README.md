# Task Manager

A microservice task management app built with TypeScript.

## Architecture

- **api/** — Express REST API (port 3000). Connects to Postgres for persistence and Redis for caching + pub/sub.
- **worker/** — Background worker that subscribes to Redis events and processes tasks asynchronously.
- **ui/** — React + Vite dashboard that talks to the API.

## Dependencies

- PostgreSQL — task storage
- Redis — caching, pub/sub between API and worker

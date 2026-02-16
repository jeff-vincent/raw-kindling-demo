# Polyglot Store — Kindling Demo

A 14-service e-commerce platform demonstrating every language supported by `kindling generate`.

## Services

| Service | Language | Port | Dependencies | Description |
|---------|----------|------|--------------|-------------|
| **gateway** | Go | 8080 | postgres | API gateway — routes to all backend services |
| **auth** | TypeScript | 3001 | redis | Authentication — JWT tokens, Redis sessions |
| **catalog** | Python | 3002 | postgres | Product catalog — CRUD for products |
| **orders** | Java | 3003 | postgres, rabbitmq | Order processing — Spring Boot + AMQP events |
| **payments** | Rust | 3004 | postgres | Payment processing — Actix-web + tokio-postgres |
| **notifications** | Ruby | 3005 | redis, rabbitmq | Notification service — Sinatra + Bunny |
| **search** | PHP | 3006 | elasticsearch | Full-text search — Slim + Elasticsearch client |
| **analytics** | C# | 3007 | postgres | Event analytics — ASP.NET minimal API + EF Core |
| **recommendations** | Elixir | 3008 | redis, postgres | Recommendation engine — Plug + Redix |
| **streaming** | Scala | 3009 | kafka | Event streaming — Akka HTTP + Kafka producer |
| **inventory** | Swift | 3010 | postgres | Inventory management — Vapor + Fluent |
| **shipping** | Dart | 3011 | redis | Shipping/logistics — shelf + Redis |
| **reviews** | Clojure | 3012 | mongodb | Product reviews — Ring + Monger |
| **pricing** | Haskell | 3013 | redis | Dynamic pricing engine — Scotty + Hedis |

## Architecture

```
                    ┌──────────┐
                    │ gateway  │ (Go :8080)
                    └────┬─────┘
        ┌───────┬───────┬┴──────┬────────┬────────┐
        ▼       ▼       ▼      ▼        ▼        ▼
     catalog  orders  search inventory reviews  pricing
     (Py)     (Java)  (PHP)  (Swift)   (Clj)   (Hs)
        │       │       │      │        │        │
        ▼       ▼       ▼      ▼        ▼        ▼
     postgres  postgres elastic postgres mongodb redis
               rabbitmq
        
     auth ──► redis       notifications ──► redis + rabbitmq
     analytics ──► postgres   recommendations ──► redis + postgres
     payments ──► postgres    streaming ──► kafka
     shipping ──► redis
```

## Quick Start with Kindling

```bash
kindling init
kindling generate -k <your-api-key> -r .
git add . && git commit -m "add workflow" && git push
```

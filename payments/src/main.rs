use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use serde::{Deserialize, Serialize};
use tokio_postgres::NoTls;
use std::env;

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
}

#[derive(Deserialize)]
struct PaymentRequest {
    order_id: String,
    user_id: String,
    amount: f64,
    currency: String,
}

#[derive(Serialize)]
struct PaymentResponse {
    id: String,
    order_id: String,
    status: String,
    amount: f64,
    currency: String,
}

struct AppState {
    db: tokio_postgres::Client,
}

async fn health() -> HttpResponse {
    HttpResponse::Ok().json(HealthResponse {
        status: "ok".to_string(),
        service: "payments".to_string(),
    })
}

async fn create_payment(
    data: web::Data<AppState>,
    body: web::Json<PaymentRequest>,
) -> HttpResponse {
    let id = uuid::Uuid::new_v4().to_string();

    let result = data.db.execute(
        "INSERT INTO payments (id, order_id, user_id, amount, currency, status) VALUES ($1, $2, $3, $4, $5, 'COMPLETED')",
        &[&id, &body.order_id, &body.user_id, &body.amount, &body.currency],
    ).await;

    match result {
        Ok(_) => HttpResponse::Created().json(PaymentResponse {
            id,
            order_id: body.order_id.clone(),
            status: "COMPLETED".to_string(),
            amount: body.amount,
            currency: body.currency.clone(),
        }),
        Err(e) => HttpResponse::InternalServerError().json(
            serde_json::json!({"error": e.to_string()})
        ),
    }
}

async fn list_payments(data: web::Data<AppState>) -> HttpResponse {
    let rows = data.db.query(
        "SELECT id, order_id, amount, currency, status FROM payments", &[]
    ).await;

    match rows {
        Ok(rows) => {
            let payments: Vec<serde_json::Value> = rows.iter().map(|row| {
                serde_json::json!({
                    "id": row.get::<_, String>(0),
                    "order_id": row.get::<_, String>(1),
                    "amount": row.get::<_, f64>(2),
                    "currency": row.get::<_, String>(3),
                    "status": row.get::<_, String>(4),
                })
            }).collect();
            HttpResponse::Ok().json(payments)
        }
        Err(e) => HttpResponse::InternalServerError().json(
            serde_json::json!({"error": e.to_string()})
        ),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let db_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "host=localhost user=postgres password=postgres dbname=payments".to_string());

    let (client, connection) = tokio_postgres::connect(&db_url, NoTls)
        .await
        .expect("Failed to connect to database");

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("Database connection error: {}", e);
        }
    });

    client.execute(
        "CREATE TABLE IF NOT EXISTS payments (
            id VARCHAR(36) PRIMARY KEY,
            order_id VARCHAR(255) NOT NULL,
            user_id VARCHAR(255) NOT NULL,
            amount DOUBLE PRECISION NOT NULL,
            currency VARCHAR(3) NOT NULL,
            status VARCHAR(20) NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        )", &[]
    ).await.expect("Failed to create table");

    let data = web::Data::new(AppState { db: client });
    let port: u16 = env::var("PORT").unwrap_or_else(|_| "3004".to_string()).parse().unwrap();

    println!("Payments service listening on :{}", port);
    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/health", web::get().to(health))
            .route("/payments", web::get().to(list_payments))
            .route("/payments", web::post().to(create_payment))
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}

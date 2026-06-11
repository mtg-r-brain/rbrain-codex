use axum::{routing::get, Json, Router};
use serde_json::json;
use std::net::SocketAddr;

const CONTEXT_NAME: &str = "oracle";

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let app = Router::new().route("/health", get(health));
    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));

    tracing::info!(%addr, context = CONTEXT_NAME, "starting rbrain service");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind 0.0.0.0:8080");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("axum serve");
}

async fn health() -> Json<serde_json::Value> {
    Json(json!({ "status": "ok", "context": CONTEXT_NAME }))
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("install ctrl_c handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}

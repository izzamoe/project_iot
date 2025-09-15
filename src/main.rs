use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use rumqttc::{AsyncClient, MqttOptions, Packet, QoS};
use serde_json::json;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::broadcast;
use tokio::sync::RwLock;
use tracing::{error, info, warn};
use uuid::Uuid;
use warp::ws::{Message, WebSocket};
use warp::Filter;

#[derive(Parser, Debug)]
#[command(name = "parking-iot-rust")]
#[command(about = "High-performance parking IoT management system written in Rust")]
struct Args {
    /// Port to run the web server on
    #[arg(short, long, default_value = "3000")]
    port: u16,

    /// MQTT broker host
    #[arg(long, default_value = "localhost")]
    mqtt_host: String,

    /// MQTT broker port
    #[arg(long, default_value = "1883")]
    mqtt_port: u16,

    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
}

type Clients = Arc<RwLock<HashMap<String, tokio::sync::mpsc::UnboundedSender<Result<Message, warp::Error>>>>>;

#[derive(Clone)]
struct AppState {
    clients: Clients,
    mqtt_sender: broadcast::Sender<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Initialize logging
    let subscriber = tracing_subscriber::fmt()
        .with_max_level(if args.debug {
            tracing::Level::DEBUG
        } else {
            tracing::Level::INFO
        })
        .finish();
    tracing::subscriber::set_global_default(subscriber)?;

    info!("🦀 Starting Rust Parking IoT Management System");
    info!("📡 Connecting to MQTT broker at {}:{}", args.mqtt_host, args.mqtt_port);

    // Create broadcast channel for MQTT messages
    let (mqtt_tx, _) = broadcast::channel::<String>(100);

    // Initialize application state
    let clients: Clients = Arc::new(RwLock::new(HashMap::new()));
    let app_state = AppState {
        clients: clients.clone(),
        mqtt_sender: mqtt_tx.clone(),
    };

    // Start MQTT client
    let mqtt_state = app_state.clone();
    tokio::spawn(async move {
        if let Err(e) = start_mqtt_client(&args.mqtt_host, args.mqtt_port, mqtt_state).await {
            error!("MQTT client error: {}", e);
        }
    });

    // WebSocket route
    let ws_route = warp::path("socket.io")
        .and(warp::ws())
        .and(with_state(app_state.clone()))
        .and_then(websocket_handler);

    // Static file serving
    let static_files = warp::path::end()
        .and(warp::fs::file("index.html"))
        .or(warp::path("public").and(warp::fs::dir("public")))
        .or(warp::path("index.js").and(warp::fs::file("index.js")));

    // Health check endpoint
    let health = warp::path("health")
        .map(|| warp::reply::json(&json!({"status": "ok", "service": "parking-iot-rust"})));

    // Combine all routes
    let routes = ws_route
        .or(static_files)
        .or(health)
        .with(
            warp::cors()
                .allow_any_origin()
                .allow_headers(vec!["content-type"])
                .allow_methods(vec!["GET", "POST", "OPTIONS"]),
        )
        .with(warp::log("parking-iot"));

    let addr: SocketAddr = ([0, 0, 0, 0], args.port).into();
    info!("🚀 Server running on http://{}", addr);
    info!("🌐 Access the parking management interface at http://localhost:{}", args.port);

    warp::serve(routes).run(addr).await;

    Ok(())
}

fn with_state(
    state: AppState,
) -> impl Filter<Extract = (AppState,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || state.clone())
}

async fn websocket_handler(
    ws: warp::ws::Ws,
    state: AppState,
) -> Result<impl warp::Reply, warp::Rejection> {
    Ok(ws.on_upgrade(move |socket| websocket_connection(socket, state)))
}

async fn websocket_connection(ws: WebSocket, state: AppState) {
    let client_id = Uuid::new_v4().to_string();
    info!("🔌 New WebSocket client connected: {}", client_id);

    let (mut ws_tx, mut ws_rx) = ws.split();
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    // Add client to the clients map
    state.clients.write().await.insert(client_id.clone(), tx);

    // Subscribe to MQTT messages
    let mut mqtt_rx = state.mqtt_sender.subscribe();

    // Handle outgoing messages (from MQTT to WebSocket)
    let client_id_clone = client_id.clone();
    let clients_clone = state.clients.clone();
    tokio::spawn(async move {
        loop {
            tokio::select! {
                // Handle MQTT messages
                mqtt_msg = mqtt_rx.recv() => {
                    match mqtt_msg {
                        Ok(message) => {
                            let socket_msg = Message::text(message);
                            if let Err(_) = ws_tx.send(socket_msg).await {
                                break;
                            }
                        }
                        Err(broadcast::error::RecvError::Closed) => break,
                        Err(broadcast::error::RecvError::Lagged(_)) => {
                            warn!("WebSocket client {} lagged behind", client_id_clone);
                        }
                    }
                }
                // Handle messages from client send queue
                client_msg = rx.recv() => {
                    match client_msg {
                        Some(Ok(msg)) => {
                            if let Err(_) = ws_tx.send(msg).await {
                                break;
                            }
                        }
                        Some(Err(_)) | None => break,
                    }
                }
            }
        }

        // Clean up when connection closes
        clients_clone.write().await.remove(&client_id_clone);
        info!("🔌 WebSocket client disconnected: {}", client_id_clone);
    });

    // Handle incoming messages from WebSocket (currently just log them)
    while let Some(result) = ws_rx.next().await {
        match result {
            Ok(msg) => {
                if msg.is_text() {
                    if let Ok(text) = msg.to_str() {
                        info!("📨 Received from client {}: {}", client_id, text);
                    }
                }
            }
            Err(e) => {
                error!("WebSocket error for client {}: {}", client_id, e);
                break;
            }
        }
    }
}

async fn start_mqtt_client(
    host: &str,
    port: u16,
    state: AppState,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut mqttoptions = MqttOptions::new("parking-iot-rust", host, port);
    mqttoptions.set_keep_alive(std::time::Duration::from_secs(60));

    let (client, mut eventloop) = AsyncClient::new(mqttoptions, 10);

    // Subscribe to parking topics
    client.subscribe("Parkir/1", QoS::AtMostOnce).await?;
    client.subscribe("Parkir/2", QoS::AtMostOnce).await?;
    info!("📡 Subscribed to MQTT topics: Parkir/1, Parkir/2");

    loop {
        match eventloop.poll().await {
            Ok(event) => {
                if let rumqttc::Event::Incoming(Packet::Publish(publish)) = event {
                    let topic = &publish.topic;
                    let payload = String::from_utf8_lossy(&publish.payload);
                    
                    info!("📡 MQTT message received - Topic: {}, Payload: {}", topic, payload);

                    // Create Socket.IO compatible message format
                    let socket_message = match topic.as_str() {
                        "Parkir/1" => {
                            json!([
                                "parkir1",
                                {
                                    "topic": topic,
                                    "message": payload.to_string(),
                                    "timestamp": chrono::Utc::now().to_rfc3339()
                                }
                            ]).to_string()
                        }
                        "Parkir/2" => {
                            json!([
                                "parkir2", 
                                {
                                    "topic": topic,
                                    "message": payload.to_string(),
                                    "timestamp": chrono::Utc::now().to_rfc3339()
                                }
                            ]).to_string()
                        }
                        _ => continue,
                    };

                    // Broadcast to all WebSocket clients
                    if let Err(e) = state.mqtt_sender.send(socket_message) {
                        warn!("Failed to broadcast MQTT message: {}", e);
                    }
                }
            }
            Err(e) => {
                error!("MQTT connection error: {}", e);
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                info!("🔄 Attempting to reconnect to MQTT broker...");
            }
        }
    }
}
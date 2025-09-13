package main

import (
	"log"
	"os"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-contrib/cors"
	"github.com/gin-contrib/static"
	"github.com/gin-gonic/gin"
	socketio "github.com/googollee/go-socket.io"
)

var (
	mqttClient mqtt.Client
	server     *socketio.Server
)

// MQTT message handler
func onMessageReceived(client mqtt.Client, msg mqtt.Message) {
	topic := msg.Topic()
	message := string(msg.Payload())
	
	log.Printf("Received MQTT message: topic=%s, message=%s", topic, message)
	
	// Emit to all connected socket.io clients
	if server != nil {
		server.BroadcastToNamespace("/", topic, message)
	}
}

// Initialize MQTT client
func initMQTT() {
	// Get MQTT broker address from environment variable or use default
	brokerHost := os.Getenv("MQTT_BROKER_HOST")
	if brokerHost == "" {
		brokerHost = "127.0.0.1"
	}
	
	brokerURL := "tcp://" + brokerHost + ":1883"
	log.Printf("Connecting to MQTT broker at: %s", brokerURL)
	
	opts := mqtt.NewClientOptions()
	opts.AddBroker(brokerURL)
	opts.SetClientID("parking-iot-go")
	opts.SetDefaultPublishHandler(onMessageReceived)
	
	mqttClient = mqtt.NewClient(opts)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		log.Printf("MQTT connection failed: %v", token.Error())
	} else {
		log.Println("Connected to MQTT broker")
		
		// Subscribe to parking topics
		if token := mqttClient.Subscribe("Parkir/1", 0, onMessageReceived); token.Wait() && token.Error() != nil {
			log.Printf("Failed to subscribe to Parkir/1: %v", token.Error())
		}
		
		if token := mqttClient.Subscribe("Parkir/2", 0, onMessageReceived); token.Wait() && token.Error() != nil {
			log.Printf("Failed to subscribe to Parkir/2: %v", token.Error())
		}
		
		log.Println("Subscribed to MQTT topics: Parkir/1, Parkir/2")
	}
}

// Initialize Socket.IO server
func initSocketIO() *socketio.Server {
	server := socketio.NewServer(nil)

	server.OnConnect("/", func(c socketio.Conn) error {
		log.Printf("Socket.IO client connected: %s", c.ID())
		return nil
	})

	server.OnDisconnect("/", func(c socketio.Conn, reason string) {
		log.Printf("Socket.IO client disconnected: %s, reason: %s", c.ID(), reason)
	})

	return server
}

func main() {
	// Initialize MQTT
	initMQTT()
	defer mqttClient.Disconnect(250)

	// Initialize Socket.IO
	server = initSocketIO()
	defer server.Close()

	// Initialize Gin router
	r := gin.Default()

	// Configure CORS - same as Node.js version with origin: "*"
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowHeaders = []string{"*"}
	r.Use(cors.New(config))

	// Serve static files from public directory
	r.Use(static.Serve("/", static.LocalFile("./public", false)))

	// Socket.IO endpoint
	r.GET("/socket.io/", gin.WrapH(server))
	r.POST("/socket.io/", gin.WrapH(server))

	// Root route - serve index.html
	r.GET("/", func(c *gin.Context) {
		c.File("./index.html")
	})

	// Start server on port 3000 (same as Node.js version)
	log.Println("Server is running on port 3000")
	if err := r.Run(":3000"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
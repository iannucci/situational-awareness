const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { Pool } = require("pg");
const WebSocket = require("ws");
const http = require("http");

// Route imports with error handling
let incidentsRouter, personnelRouter, sheltersRouter;

try {
    incidentsRouter = require("./routes/incidents");
} catch (err) {
    console.warn("incidents route not found, creating placeholder");
    incidentsRouter = express.Router();
    incidentsRouter.get("/active", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    personnelRouter = require("./routes/personnel");
} catch (err) {
    console.warn("personnel route not found, creating placeholder");
    personnelRouter = express.Router();
    personnelRouter.get("/status", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    sheltersRouter = require("./routes/shelters");
} catch (err) {
    console.warn("shelters route not found, creating placeholder");
    sheltersRouter = express.Router();
    sheltersRouter.get("/available", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

// Configuration
const config = {
    port: process.env.PORT || 3000,
    database: {
        host: process.env.DB_HOST || "localhost",
        port: process.env.DB_PORT || 5432,
        database: process.env.DB_NAME || "palo_alto_emergency",
        user: process.env.DB_USER || "emergency_user",
        password: process.env.DB_PASSWORD || "emergency_pass"
    }
};

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Database connection pool
const pool = new Pool(config.database);

// Test database connection
pool.connect((err, client, done) => {
    if (err) {
        console.error("Database connection error:", err);
        console.log("Continuing without database connection...");
    } else {
        console.log("✅ Connected to PostgreSQL database");
        done();
    }
});

app.set("db", pool);

// Middleware
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Rate limiting
const limiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 1000,
    message: { success: false, error: { code: "RATE_LIMIT_EXCEEDED", message: "Too many requests" } }
});
app.use("/api", limiter);

// Request logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
});

// API Routes
app.use("/api/v1/incidents", incidentsRouter);
app.use("/api/v1/personnel", personnelRouter);
app.use("/api/v1/shelters", sheltersRouter);

// Health check endpoint
app.get("/api/health", async (req, res) => {
    try {
        await pool.query("SELECT NOW()");
        res.json({
            success: true,
            status: "healthy",
            timestamp: new Date().toISOString(),
            services: { database: "connected", api: "running" }
        });
    } catch (error) {
        res.json({
            success: true,
            status: "partial", 
            timestamp: new Date().toISOString(),
            services: { database: "disconnected", api: "running" }
        });
    }
});

// API root endpoint
app.get("/api/v1", (req, res) => {
    res.json({
        success: true,
        message: "Palo Alto Emergency Response System API",
        version: "1.0.0",
        endpoints: {
            incidents: "/api/v1/incidents/active",
            personnel: "/api/v1/personnel/status",
            shelters: "/api/v1/shelters/available"
        },
        timestamp: new Date().toISOString()
    });
});

// WebSocket setup
const wss = new WebSocket.Server({ server, path: "/ws" });
const wsClients = new Set();

wss.on("connection", (ws, req) => {
    console.log("WebSocket client connected");
    wsClients.add(ws);
    
    ws.send(JSON.stringify({
        type: "connection",
        message: "Connected to Emergency Response System",
        timestamp: new Date().toISOString()
    }));
    
    ws.on("close", () => { wsClients.delete(ws); });
    ws.on("error", (error) => { console.error("WebSocket error:", error); wsClients.delete(ws); });
});

// Error handling
app.use((err, req, res, next) => {
    console.error("API Error:", err);
    res.status(500).json({
        success: false,
        error: { code: "INTERNAL_ERROR", message: "Internal server error" }
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: { code: "NOT_FOUND", message: `Endpoint ${req.method} ${req.path} not found` }
    });
});

// Start server
server.listen(config.port, () => {
    console.log(`
🚨 Emergency Response System API Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 Server: http://localhost:${config.port}
  📊 Health: http://localhost:${config.port}/api/health
  🔗 API Root: http://localhost:${config.port}/api/v1
  🔗 WebSocket: ws://localhost:${config.port}/ws
  📍 Service Area: Palo Alto, California
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚑 Ready for emergency response operations
    `);
});

module.exports = { app, server, pool };

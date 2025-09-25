const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const { Pool } = require("pg");
const WebSocket = require("ws");
const http = require("http");
const path = require("path");

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

console.log("🚨 [server] Situational Awareness API Starting...");

// Route imports with error handling
let incidentsRouter, assetsRouter; logsRouter

try {
    incidentsRouter = require("./routes/incidents");
    console.log("✅ [server] Loaded incidents routes");
} catch (err) {
    console.warn("⚠️ [server] incidents route not found, creating placeholder");
    incidentsRouter = express.Router();
    incidentsRouter.get("/active", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    assetsRouter = require("./routes/assets");
    console.log("✅ [server] Loaded assets routes");
} catch (err) {
    console.warn("⚠️ [server] assets route not found, creating placeholder");
    assetsRouter = express.Router();
    assetsRouter.get("/status", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    logsRouter = require("./routes/logs");
    console.log("✅ [server] Loaded remote logging routes");
} catch (err) {
    console.warn("⚠️ [server] logs route not found, creating placeholder");
    logsRouter = express.Router();
    logsRouter.get("/entry", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

// Configuration
const config = {
    port: process.env.PORT || 3000,
    database: {
        host: process.env.DB_HOST || "localhost",
        port: parseInt(process.env.DB_PORT) || 5432,
        database: process.env.DB_NAME || "palo_alto_emergency",
        user: process.env.DB_USER || "emergency_user",
        password: process.env.DB_PASSWORD || "emergency_pass",
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 30000,
        max: 20,
        idleTimeoutMillis: 30000,
    }
};

console.log("📝 [server] Configuration loaded:", {
    port: config.port,
    database: {
        host: config.database.host,
        port: config.database.port,
        database: config.database.database,
        user: config.database.user,
        ssl: config.database.ssl
    }
});

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Database connection pool with better error handling
let pool = null;
try {
    pool = new Pool(config.database);
    
    // Test database connection with timeout
    const testConnection = async () => {
        try {
            const client = await pool.connect();
            console.log("🔌 [server] Testing database connection...");
            const result = await client.query('SELECT NOW() as current_time');
            console.log("✅ [server] Database connection successful:", result.rows[0].current_time);
            client.release();
            return true;
        } catch (err) {
            console.error("❌ [server] Database connection failed:", err.message);
            console.log("⚠️ [server] Continuing without database connection (using mock data)");
            return false;
        }
    };

    // Test connection on startup
    testConnection().then((connected) => {
        if (connected) {
            app.set("db", pool);
            console.log("✅ [server] Database pool configured and ready");
        } else {
            console.log("⚠️ [server] Running without database connection");
        }
    });

    // Handle pool errors
    pool.on('error', (err) => {
        console.error('❌ [server] Database pool error:', err);
    });

} catch (error) {
    console.error("❌ [server] Failed to create database pool:", error.message);
    console.log("⚠️ [server] Continuing without database connection...");
}

// Middleware
app.use(helmet({ 
    contentSecurityPolicy: false, 
    crossOriginEmbedderPolicy: false,
    crossOriginResourcePolicy: { policy: "cross-origin" }
}));

app.use(cors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

app.use(compression());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: "RATE_LIMIT_EXCEEDED", message: "Too many requests" } }
});
app.use("/api", limiter);

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
});

// API Routes
app.use("/api/v1/incidents", incidentsRouter);
app.use("/api/v1/assets", assetsRouter);

// Health check endpoint with more comprehensive checks
app.get("/api/health", async (req, res) => {
    const health = {
        success: true,
        status: "healthy",
        timestamp: new Date().toISOString(),
        services: {
            api: "running",
            database: "unknown",
            routes: "loaded"
        },
        version: "1.0.0",
        uptime: process.uptime()
    };

    try {
        if (pool) {
            const client = await pool.connect();
            await client.query('SELECT NOW()');
            client.release();
            health.services.database = "connected";
        } else {
            health.services.database = "disconnected";
            health.status = "partial";
        }
    } catch (error) {
        console.error("[server] Health check database error:", error.message);
        health.services.database = "error";
        health.status = "partial";
    }

    const statusCode = health.status === "healthy" ? 200 : 206;
    res.status(statusCode).json(health);
});

// API root endpoint
app.get("/api/v1", (req, res) => {
    res.json({
        success: true,
        message: "Palo Alto Situational Awareness API",
        version: "1.0.0",
        endpoints: {
            health: "/api/health",
            incidents: "/api/v1/incidents/active",
            assets: "/api/v1/assets/status",
        },
        documentation: "https://github.com/iannucci/situational-awareness",
        timestamp: new Date().toISOString()
    });
});

// WebSocket setup for real-time updates
const wss = new WebSocket.Server({ server, path: "/ws" });
const wsClients = new Set();

wss.on("connection", (ws, req) => {
    console.log("🔌 [server] WebSocket client connected from:", req.socket.remoteAddress);
    wsClients.add(ws);
    
    ws.send(JSON.stringify({
        type: "connection",
        message: "Connected to Situational Awareness system",
        timestamp: new Date().toISOString()
    }));
    
    ws.on("close", () => { 
        console.log("🔌 [server] WebSocket client disconnected");
        wsClients.delete(ws); 
    });
    
    ws.on("error", (error) => { 
        console.error("[server] WebSocket error:", error); 
        wsClients.delete(ws); 
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error("🚨 [server] API Error:", err);
    res.status(500).json({
        success: false,
        error: { 
            code: "INTERNAL_ERROR", 
            message: process.env.NODE_ENV === 'production' ? "Internal server error" : err.message 
        }
    });
});

// 404 handler
app.use((req, res) => {
    console.log(`404 - Not found: ${req.method} ${req.path}`);
    res.status(404).json({
        success: false,
        error: { code: "NOT_FOUND", message: `Endpoint ${req.method} ${req.path} not found` }
    });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🔄 [server] Received SIGTERM, shutting down gracefully');
    server.close(() => {
        console.log('✅ [server] HTTP server closed');
        if (pool) {
            pool.end(() => {
                console.log('✅ [server] Database pool closed');
                process.exit(0);
            });
        } else {
            process.exit(0);
        }
    });
});

process.on('SIGINT', async () => {
    console.log('🔄 [server] Received SIGINT, shutting down gracefully');
    server.close(() => {
        console.log('✅ [erver] HTTP server closed');
        if (pool) {
            pool.end(() => {
                console.log('✅ [server] Database pool closed');
                process.exit(0);
            });
        } else {
            process.exit(0);
        }
    });
});

// Start server
server.listen(config.port, () => {
    console.log(`
🚨 [server] Situational Awareness API Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 Server: http://localhost:${config.port}
  📊 Health: http://localhost:${config.port}/api/health
  🔗 API Root: http://localhost:${config.port}/api/v1
  🔗 WebSocket: ws://localhost:${config.port}/ws
  📍 Service Area: Palo Alto, California
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚒 [server] Ready for situational awareness operations
    `);
});

module.exports = { app, server, pool };

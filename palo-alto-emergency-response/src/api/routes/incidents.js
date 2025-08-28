const express = require("express");
const router = express.Router();

router.get("/active", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockIncidents(),
                count: getMockIncidents().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const result = await pool.query("SELECT * FROM active_incidents_view LIMIT 10");
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockIncidents(),
                count: getMockIncidents().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("Error in incidents/active:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve incidents" }
        });
    }
});

function getMockIncidents() {
    return [
        {
            id: 1,
            incident_number: "INC-2025-000001",
            incident_type: "Structure Fire",
            severity: "High",
            priority: 1,
            status: "Active",
            longitude: -122.1630,
            latitude: 37.4419,
            address: "450 University Ave",
            title: "Commercial Building Fire",
            description: "Heavy smoke showing from 2-story commercial building",
            reported_at: new Date().toISOString()
        },
        {
            id: 2,
            incident_number: "INC-2025-000002",
            incident_type: "Medical Emergency",
            severity: "Medium",
            priority: 2,
            status: "Active",
            longitude: -122.1334,
            latitude: 37.4505,
            address: "660 Stanford Shopping Center",
            title: "Medical Emergency",
            description: "Person collapsed, conscious and breathing",
            reported_at: new Date().toISOString()
        }
    ];
}

module.exports = router;

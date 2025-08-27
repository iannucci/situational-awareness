const express = require("express");
const router = express.Router();

router.get("/active", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        try {
            const result = await pool.query("SELECT * FROM active_incidents_view LIMIT 10");
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            const mockData = [
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
                }
            ];
            
            res.json({
                success: true,
                data: mockData,
                count: mockData.length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
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

module.exports = router;

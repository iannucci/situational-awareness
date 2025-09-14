const express = require("express");
const router = express.Router();

router.get("/status", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("[personnel] Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockPersonnel(),
                count: getMockPersonnel().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const query = `
                SELECT 
                    u.id as unit_id,
                    u.call_sign,
                    ut.type_name as unit_type,
                    u.status,
                    ST_X(ul.location) as longitude,
                    ST_Y(ul.location) as latitude,
                    ul.timestamp as last_update
                FROM units u
                JOIN unit_types ut ON u.unit_type_id = ut.id
                LEFT JOIN LATERAL (
                    SELECT location, timestamp 
                    FROM unit_locations 
                    WHERE unit_id = u.id 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                ) ul ON true
            `;
            const result = await pool.query(query);
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("[personnel] Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockPersonnel(),
                count: getMockPersonnel().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("[personnel] Error in personnel/status:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve personnel status" }
        });
    }
});

function getMockPersonnel() {
    return [
        {
            unit_id: "PAFD-E01",
            call_sign: "Engine 1",
            unit_type: "Fire Engine",
            status: "Available",
            longitude: -122.1576,
            latitude: 37.4614,
            last_update: new Date().toISOString()
        },
        {
            unit_id: "PAEMS-M01",
            call_sign: "Medic 1",
            unit_type: "Ambulance",
            status: "Dispatched",
            longitude: -122.1540,
            latitude: 37.4349,
            last_update: new Date().toISOString()
        },
        {
            unit_id: "PAPD-01",
            call_sign: "Unit 1",
            unit_type: "Police Unit",
            status: "On Patrol",
            longitude: -122.1560,
            latitude: 37.4419,
            last_update: new Date().toISOString()
        }
    ];
}

module.exports = router;

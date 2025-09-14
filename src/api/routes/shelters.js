const express = require("express");
const router = express.Router();

router.get("/available", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("[shelters] Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockShelters(),
                count: getMockShelters().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const query = `
                SELECT 
                    id, facility_name, facility_type,
                    ST_X(location) as longitude,
                    ST_Y(location) as latitude,
                    address, total_capacity, current_occupancy, available_capacity,
                    operational_status, has_kitchen, has_medical, wheelchair_accessible, contact_phone
                FROM shelters
                WHERE operational_status IN ('Available', 'Open')
                ORDER BY available_capacity DESC
            `;
            const result = await pool.query(query);
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("[shelters] Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockShelters(),
                count: getMockShelters().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("[shelters] Error in shelters/available:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve shelter information" }
        });
    }
});

function getMockShelters() {
    return [
        {
            id: "SHELTER-01",
            facility_name: "Mitchell Park Community Center",
            facility_type: "Community Center",
            longitude: -122.1549,
            latitude: 37.4282,
            address: "3700 Middlefield Rd, Palo Alto, CA",
            total_capacity: 150,
            current_occupancy: 0,
            available_capacity: 150,
            operational_status: "Available",
            has_kitchen: true,
            has_medical: true,
            wheelchair_accessible: true,
            contact_phone: "(650) 463-4920"
        },
        {
            id: "SHELTER-02",
            facility_name: "Cubberley Community Center",
            facility_type: "Community Center",
            longitude: -122.1345,
            latitude: 37.4092,
            address: "4000 Middlefield Rd, Palo Alto, CA",
            total_capacity: 200,
            current_occupancy: 80,
            available_capacity: 120,
            operational_status: "Available",
            has_kitchen: true,
            has_medical: false,
            wheelchair_accessible: true,
            contact_phone: "(650) 463-4950"
        }
    ];
}

module.exports = router;

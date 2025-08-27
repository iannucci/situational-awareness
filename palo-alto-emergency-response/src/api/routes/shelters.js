const express = require("express");
const router = express.Router();

router.get("/available", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
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
            const mockData = [
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
        console.error("Error in shelters/available:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve shelter information" }
        });
    }
});

module.exports = router;

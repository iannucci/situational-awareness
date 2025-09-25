const express = require("express");
const router = express.Router();

router.get("/status", async (req, res) => {
    try {
        console.log("[assets] Retrieving status");
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("[assets] Database pool not available");
            return res.json({
                success: true,
                data: getMockAssets(),
                count: getMockAssets().length,
                timestamp: new Date().toISOString(),
                note: "Database not connected"
            });
        }

        try {
            const query = `
                SELECT 
                    ta.asset_id as asset_id,
                    ta.type_code as type_code,
                    ta.tactical_call as tactical_call,
                    ta.description as description,
                    ta.url as url,
                    ta.status as status,
                    tat.icon as icon,
                    ST_X(tal.location) as longitude,
                    ST_Y(tal.location) as latitude,
                    EXTRACT(EPOCH FROM tal.timestamp) as last_update
                FROM tracked_assets ta
                JOIN tracked_asset_types tat ON ta.type_code = tat.type_code
                LEFT JOIN LATERAL (
                    SELECT location, timestamp 
                    FROM tracked_asset_locations 
                    WHERE asset_id = ta.asset_id
                    ORDER BY timestamp DESC 
                    LIMIT 1
                ) tal ON true
            `;
            const result = await pool.query(query);
            console.log("[assets] Database query result:", result.rows)
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("[assets] Database query failed", dbError.message);
            res.json({
                success: true,
                data: getMockAssets(),
                count: getMockAssets().length,
                timestamp: new Date().toISOString(),
                note: "Database query failed"
            });
        }
    } catch (error) {
        console.error("[assets] Error in asset/status:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve asset status" }
        });
    }
});

function getMockAssets() {
    return [];
}

module.exports = router;

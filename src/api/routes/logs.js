const express = require("express");
const router = express.Router();

router.get("/entry", async (req, res) => {
	const level = req.get("level");
	const message = req.get("message");
	const timestamp = req.get("timestamp");
	console.log('<CLIENT> ' + message)
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

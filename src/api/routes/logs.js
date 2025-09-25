const express = require("express");
const router = express.Router();

router.post('/entry', async (req, res) => {
	const { level, message, timestamp } = req.body;
	console.log("<CLIENT> " + message);
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

const express = require("express");
const router = express.Router();

router.post('/entry', async (req, res) => {
	console.log(req.body);
	level = req.body.level
	message = req.body.message;
	console.log("<CLIENT> ", level.toUpperCase(), " ", message);
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

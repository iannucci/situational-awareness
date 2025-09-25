const express = require("express");
const router = express.Router();

router.post('/entry', async (req, res) => {
	level = req.body.level
	message = req.body.message;
	ip = req.ip.replace("::ffff:", '');
	console.log("[" + ip + "] " + message);
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

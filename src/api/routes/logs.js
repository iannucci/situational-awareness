const express = require("express");
const router = express.Router();

router.post('/entry', async (req, res) => {
	console.log("<CLIENT> " + req.body.message);
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

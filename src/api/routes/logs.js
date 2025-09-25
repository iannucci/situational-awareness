const express = require("express");
const router = express.Router();

router.post('/entry', async (req, res) => {
	console.log(req.body);
	message = req.body.message;
	console.log("<CLIENT> ", message);
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

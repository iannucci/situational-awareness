const express = require("express");
const router = express.Router();

routerpost("/entry", async (req, res) => {
	console.log('<CLIENT> ' + req)
	return res.json({
		success: true,
		data: [],
		note: "OK"
	});
})

module.exports = router;

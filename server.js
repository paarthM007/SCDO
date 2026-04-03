import express from "express";
import cors from "cors";
import { orchestrator } from "./index.js";

const app = express();
app.use(cors()); // Enable CORS for all origins
app.use(express.json());

//onRequest handles express-like req/res.
app.post("/orchestrator", (req, res) => {
    orchestrator(req, res);
});

const PORT = 8081;
app.listen(PORT, () => {
    console.log(`Orchestrator locally running on http://localhost:${PORT}/orchestrator`);
});

import { onRequest } from "firebase-functions/v2/https";
import { PubSub } from "@google-cloud/pubsub";
import { getFirestore } from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";
import { logger } from "firebase-functions";
import crypto from "crypto";

// ── Firebase Admin ──────────────────────────────────────────
const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) {
    throw new Error("GOOGLE_CLOUD_PROJECT environment variable is not set.");
}
initializeApp({ projectId });
const db = getFirestore();

// ── Pub/Sub ─────────────────────────────────────────────────
const pubsub = new PubSub({ projectId });
const TOPIC_NAME = "calculate-topic";

/**
 * Orchestrator Cloud Function
 * ───────────────────────────
 * Flow: Flutter → POST here → Firestore (pending) → Pub/Sub → Python worker
 *
 * Request body:
 *   {
 *     "cities": ["Mumbai", "Delhi", "Dubai"],
 *     "modes": ["Road", "Ship"],
 *     "cargo_type": "general",       // optional, default "general"
 *     "date": "2026-04-02",          // optional
 *     "n_iterations": 50             // optional, default 50
 *   }
 */
export const orchestrator = onRequest({ region: "us-central1" }, async (req, res) => {
    // 1. HTTP Protocol guard
    if (req.method !== "POST") {
        return res.status(405).json({ error: "Only POST requests are allowed" });
    }

    const { cities, modes, cargo_type, date, n_iterations } = req.body;

    // 2. Validation
    if (!Array.isArray(cities) || cities.length < 2) {
        return res.status(400).json({
            error: "Provide 'cities' as an array with at least 2 entries.",
        });
    }
    if (!Array.isArray(modes) || modes.length !== cities.length - 1) {
        return res.status(400).json({
            error: "Provide 'modes' as an array with exactly (cities.length - 1) entries.",
        });
    }

    // 3. Generate traceable Job ID
    const jobId = `job_${crypto.randomUUID()}`;

    try {
        // 4. Write initial job to Firestore (Flutter listens here)
        const jobDoc = {
            jobId,
            status: "pending",
            cities,
            modes,
            cargo_type: cargo_type || "general",
            date: date || null,
            n_iterations: n_iterations || 50,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            result: null,
            error: null,
        };

        await db.collection("sim_jobs").doc(jobId).set(jobDoc);
        logger.info(`Orchestrator: Created Firestore doc for ${jobId}`);

        // 5. Publish to Pub/Sub for Python worker
        const message = {
            jobId,
            cities,
            modes,
            cargo_type: cargo_type || "general",
            date: date || null,
            n_iterations: n_iterations || 50,
        };

        const messageBuffer = Buffer.from(JSON.stringify(message));
        await pubsub.topic(TOPIC_NAME).publishMessage({ data: messageBuffer });

        logger.info(`Orchestrator: Dispatched ${jobId} to Python worker via Pub/Sub.`);

        // 6. 202 Accepted — async processing started
        res.status(202).json({
            jobId,
            status: "pending",
            message: "Simulation has been queued. Listen to Firestore for results.",
            firestore_path: `sim_jobs/${jobId}`,
        });
    } catch (error) {
        console.error("Orchestrator Error Details:", error);
        logger.error("Orchestration Error:", error);
        res.status(500).json({ error: "Failed to queue simulation task.", debug: error.message });
    }
});
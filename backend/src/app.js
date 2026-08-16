import express from "express";
import cors from "cors";
import itineraryRoutes from "./routes/itineraryRoutes.js";
import routingRoutes from "./routes/routingRoutes.js";

const app = express();

// 1. Enable CORS for local cross-origin calls
app.use(cors());

// 2. Enable JSON body parser
app.use(express.json());

// 3. Log incoming requests to verify Flutter reaches Node.js
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// 4. Register API Routes
app.use("/api/itinerary", itineraryRoutes);
app.use("/api/routing", routingRoutes);

// 5. Health Check Endpoint
app.get("/api/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date() });
});

// 6. Global 404 Handler
app.use((req, res) => {
  res.status(404).json({ error: "Route not found" });
});

// 7. Global Error Handler (Prevents hanging when errors occur)
app.use((err, req, res, next) => {
  console.error("Server Error:", err);
  res.status(500).json({ error: err.message || "Internal Server Error" });
});

export default app;
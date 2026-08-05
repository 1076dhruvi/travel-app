import express from "express";
import { optimizeItinerary } from "../controllers/routingController.js";

const router = express.Router();

router.post("/optimize", optimizeItinerary);

export default router;
import express from "express";
import { generateItinerary } from "../controllers/itineraryController.js";

const router = express.Router();

router.post("/generate", generateItinerary);

export default router;
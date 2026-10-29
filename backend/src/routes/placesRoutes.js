import express from "express";
import {
  getApiKey,
  autocomplete,
  placeDetails,
  reverseGeocodeCoords,
} from "../controllers/placesController.js";

const router = express.Router();

router.get("/key", getApiKey);
router.post("/autocomplete", autocomplete);
router.post("/details", placeDetails);
router.post("/reverse-geocode", reverseGeocodeCoords);

export default router;

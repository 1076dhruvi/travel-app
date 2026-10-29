import {
  getAutocompleteSuggestions,
  getPlaceDetailsById,
  reverseGeocode,
} from "../services/placesService.js";

export const getApiKey = (req, res) => {
  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"] ||
    "";
  return res.json({ apiKey: googleApiKey });
};

export const autocomplete = async (req, res) => {
  try {
    const { input, sessionToken, destination } = req.body;
    if (!input || !input.trim()) {
      return res.json({ success: true, predictions: [] });
    }

    const predictions = await getAutocompleteSuggestions(input, sessionToken, destination);
    return res.json({ success: true, predictions });
  } catch (error) {
    console.error("Autocomplete error:", error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const placeDetails = async (req, res) => {
  try {
    const { placeId, sessionToken } = req.body;
    if (!placeId) {
      return res.status(400).json({ success: false, error: "placeId is required" });
    }

    const details = await getPlaceDetailsById(placeId, sessionToken);
    if (!details) {
      return res.status(404).json({ success: false, error: "Place details not found" });
    }

    return res.json({ success: true, place: details });
  } catch (error) {
    console.error("Place details error:", error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const reverseGeocodeCoords = async (req, res) => {
  try {
    const { lat, lon } = req.body;
    if (lat == null || lon == null) {
      return res.status(400).json({ success: false, error: "lat and lon are required" });
    }

    const name = await reverseGeocode(Number(lat), Number(lon));
    return res.json({ success: true, name });
  } catch (error) {
    console.error("Reverse geocode error:", error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
};

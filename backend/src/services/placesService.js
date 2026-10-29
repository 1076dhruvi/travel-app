import axios from "axios";
import { geocodePlace } from "./geocodeService.js";

// In-memory cache for place details to prevent redundant API calls
const placesCache = new Map();

/**
 * Normalizes opening hours into a clean, displayable string: "09:00 - 18:00"
 * or returns "check locally" if missing/unparseable.
 */
function normalizeOpeningHours(rawHours) {
  if (!rawHours) return "check locally";

  if (typeof rawHours === "string") {
    const trimmed = rawHours.trim();
    if (!trimmed || trimmed.toLowerCase().includes("null") || trimmed.toLowerCase().includes("unknown")) {
      return "check locally";
    }
    // If it's already like "09:00-18:00" or "09:00 - 18:00"
    if (/^\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}$/.test(trimmed)) {
      return trimmed;
    }
    // "Open 24 hours"
    if (trimmed.toLowerCase().includes("24 hour") || trimmed.toLowerCase().includes("24/7")) {
      return "Open 24 hours";
    }
    return trimmed;
  }

  // Google Places API opening hours object
  if (typeof rawHours === "object") {
    // Check weekdayDescriptions array (Google Places API v1)
    if (Array.isArray(rawHours.weekdayDescriptions) && rawHours.weekdayDescriptions.length > 0) {
      const todayIndex = (new Date().getDay() + 6) % 7; // Monday=0 in many locales, or find matching day
      const todayText = rawHours.weekdayDescriptions[todayIndex] || rawHours.weekdayDescriptions[0];
      const match = todayText.match(/\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\s*[-–—]\s*\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?/i);
      if (match) return match[0];
      if (todayText.toLowerCase().includes("open 24")) return "Open 24 hours";
      if (todayText.toLowerCase().includes("closed")) return "Closed today (check locally)";
    }

    // Google Places legacy weekday_text
    if (Array.isArray(rawHours.weekday_text) && rawHours.weekday_text.length > 0) {
      const todayText = rawHours.weekday_text[0];
      const match = todayText.match(/\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\s*[-–—]\s*\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?/i);
      if (match) return match[0];
      if (todayText.toLowerCase().includes("open 24")) return "Open 24 hours";
    }

    // Check periods
    if (Array.isArray(rawHours.periods) && rawHours.periods.length > 0) {
      const period = rawHours.periods[0];
      if (period.open && period.close) {
        const openTime = period.open.time || `${period.open.hour}:${period.open.minute || "00"}`;
        const closeTime = period.close.time || `${period.close.hour}:${period.close.minute || "00"}`;
        return `${openTime} - ${closeTime}`;
      }
    }
  }

  return "check locally";
}

/**
 * Fetch verified place coordinates and real opening hours via Google Places API,
 * with graceful fallback to geocodeService and "check locally".
 */
export async function getPlaceDetails(placeName, city = "") {
  if (!placeName || typeof placeName !== "string") {
    return null;
  }

  const cacheKey = `${city.toLowerCase()}_${placeName.toLowerCase()}`.trim();
  if (placesCache.has(cacheKey)) {
    return placesCache.get(cacheKey);
  }

  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  const queryText = city ? `${placeName}, ${city}` : placeName;

  // 1. Try Google Places API (New Text Search)
  if (googleApiKey) {
    try {
      const response = await axios.post(
        "https://places.googleapis.com/v1/places:searchText",
        {
          textQuery: queryText,
          maxResultCount: 1,
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": googleApiKey,
            "X-Goog-FieldMask":
              "places.id,places.displayName,places.formattedAddress,places.location,places.regularOpeningHours,places.currentOpeningHours",
          },
          timeout: 6000,
        }
      );

      const place = response.data?.places?.[0];
      if (place && place.location) {
        const openingHours =
          normalizeOpeningHours(place.regularOpeningHours) ||
          normalizeOpeningHours(place.currentOpeningHours) ||
          "check locally";

        const result = {
          placeId: place.id || `${place.location.latitude},${place.location.longitude}`,
          name: place.displayName?.text || placeName,
          lat: place.location.latitude,
          lon: place.location.longitude,
          openingHours: openingHours,
          address: place.formattedAddress || "",
        };

        placesCache.set(cacheKey, result);
        return result;
      }
    } catch (apiError) {
      // Continue to legacy search or geocode fallback
    }

    // 2. Try Google Places Legacy Text Search
    try {
      const legacyRes = await axios.get(
        "https://maps.googleapis.com/maps/api/place/textsearch/json",
        {
          params: {
            query: queryText,
            key: googleApiKey,
          },
          timeout: 5000,
        }
      );

      const candidate = legacyRes.data?.results?.[0];
      if (candidate && candidate.geometry?.location) {
        let hours = "check locally";
        if (candidate.opening_hours) {
          hours = normalizeOpeningHours(candidate.opening_hours);
        }

        const result = {
          placeId: candidate.place_id || `${candidate.geometry.location.lat},${candidate.geometry.location.lng}`,
          name: candidate.name || placeName,
          lat: candidate.geometry.location.lat,
          lon: candidate.geometry.location.lng,
          openingHours: hours,
          address: candidate.formatted_address || "",
        };

        placesCache.set(cacheKey, result);
        return result;
      }
    } catch (legacyErr) {
      // Continue to geocode fallback
    }
  }

  // 3. Fallback to existing geocodeService (Geoapify)
  try {
    const geo = await geocodePlace(placeName, city);
    if (geo) {
      const result = {
        placeId: geo.placeId || `${geo.lat},${geo.lng ?? geo.lon}`,
        name: geo.name || placeName,
        lat: geo.lat,
        lon: geo.lng ?? geo.lon,
        openingHours: "check locally",
        address: city,
      };
      placesCache.set(cacheKey, result);
      return result;
    }
  } catch (geoErr) {
    // Fallback handled below
  }

  return null;
}

export async function getCityCenter(cityName) {
  if (!cityName) return null;

  const cacheKey = `city_center_${cityName.toLowerCase()}`.trim();
  if (placesCache.has(cacheKey)) {
    return placesCache.get(cacheKey);
  }

  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  if (googleApiKey) {
    try {
      const response = await axios.get(
        "https://maps.googleapis.com/maps/api/place/textsearch/json",
        {
          params: {
            query: `${cityName}, India`,
            key: googleApiKey,
          },
          timeout: 5000,
        }
      );

      const candidate = response.data?.results?.[0];
      if (candidate && candidate.geometry?.location) {
        const result = {
          name: candidate.name || cityName,
          lat: candidate.geometry.location.lat,
          lon: candidate.geometry.location.lng,
          address: candidate.formatted_address || cityName,
        };
        placesCache.set(cacheKey, result);
        return result;
      }
    } catch (_) {}
  }

  // Fallback
  try {
    const geo = await geocodePlace(cityName);
    if (geo) {
      const result = {
        name: geo.name || cityName,
        lat: geo.lat,
        lon: geo.lng ?? geo.lon,
        address: cityName,
      };
      placesCache.set(cacheKey, result);
      return result;
    }
  } catch (_) {}

  return null;
}

/**
 * Autocomplete place predictions using Google Places API (India-biased, with session token)
 */
export async function getAutocompleteSuggestions(input, sessionToken = null, destination = "") {
  if (!input || typeof input !== "string" || input.trim().length === 0) {
    return [];
  }

  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  if (!googleApiKey) {
    // Fallback to geoapify autocomplete if Google key missing
    try {
      const encoded = encodeURIComponent(input.trim());
      const geoUrl = `https://api.geoapify.com/v1/geocode/autocomplete?text=${encoded}&limit=5&filter=countrycode:in&apiKey=${process.env["GEOAPIFY_API_KEY"] || "70101d58fc2d4441a91d29558f9157bb"}`;
      const geoRes = await axios.get(geoUrl, { timeout: 4000 });
      const features = geoRes.data?.features || [];
      return features.map((f) => ({
        placeId: f.properties?.place_id || f.properties?.osm_id || `${f.properties?.lat},${f.properties?.lon}`,
        primaryText: f.properties?.name || f.properties?.city || f.properties?.formatted,
        secondaryText: [f.properties?.city, f.properties?.state, f.properties?.country].filter(Boolean).join(", "),
        fullText: f.properties?.formatted || f.properties?.name,
        lat: f.properties?.lat,
        lon: f.properties?.lon,
      }));
    } catch (_) {
      return [];
    }
  }

  try {
    const params = {
      input: input.trim(),
      key: googleApiKey,
      components: "country:in",
    };

    if (sessionToken) {
      params.sessiontoken = sessionToken;
    }

    const response = await axios.get(
      "https://maps.googleapis.com/maps/api/place/autocomplete/json",
      {
        params,
        timeout: 5000,
      }
    );

    const predictions = response.data?.predictions || [];
    return predictions.map((p) => ({
      placeId: p.place_id,
      primaryText: p.structured_formatting?.main_text || p.description,
      secondaryText: p.structured_formatting?.secondary_text || "",
      fullText: p.description,
    }));
  } catch (err) {
    console.warn("Places autocomplete error:", err.message);
    return [];
  }
}

/**
 * Fetch authoritative coordinates and details for a selected placeId
 */
export async function getPlaceDetailsById(placeId, sessionToken = null) {
  if (!placeId) return null;

  const cacheKey = `place_id_${placeId}`;
  if (placesCache.has(cacheKey)) {
    return placesCache.get(cacheKey);
  }

  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  if (googleApiKey) {
    try {
      const params = {
        place_id: placeId,
        key: googleApiKey,
        fields: "name,geometry,formatted_address,opening_hours",
      };

      if (sessionToken) {
        params.sessiontoken = sessionToken;
      }

      const response = await axios.get(
        "https://maps.googleapis.com/maps/api/place/details/json",
        {
          params,
          timeout: 5000,
        }
      );

      const candidate = response.data?.result;
      if (candidate && candidate.geometry?.location) {
        let hours = "check locally";
        if (candidate.opening_hours) {
          hours = normalizeOpeningHours(candidate.opening_hours);
        }

        const result = {
          name: candidate.name,
          lat: candidate.geometry.location.lat,
          lon: candidate.geometry.location.lng,
          address: candidate.formatted_address || "",
          openingHours: hours,
        };

        placesCache.set(cacheKey, result);
        return result;
      }
    } catch (err) {
      console.warn("Place details error:", err.message);
    }
  }

  // If placeId happens to be "lat,lon" from Geoapify fallback
  if (placeId.includes(",")) {
    const [lat, lon] = placeId.split(",").map(Number);
    if (!isNaN(lat) && !isNaN(lon)) {
      return {
        name: "Selected Location",
        lat: lat,
        lon: lon,
        address: "",
        openingHours: "check locally",
      };
    }
  }

  return null;
}

/**
 * Reverse geocodes coordinates to a clean place/neighborhood name
 */
export async function reverseGeocode(lat, lon) {
  if (lat == null || lon == null) return null;

  const cacheKey = `rev_geo_${Number(lat).toFixed(4)},${Number(lon).toFixed(4)}`;
  if (placesCache.has(cacheKey)) {
    return placesCache.get(cacheKey);
  }

  const googleApiKey =
    process.env["GOOGLE_PLACES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  if (googleApiKey) {
    try {
      const response = await axios.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        {
          params: {
            latlng: `${lat},${lon}`,
            key: googleApiKey,
          },
          timeout: 5000,
        }
      );

      const results = response.data?.results || [];
      if (results.length > 0) {
        // Find best neighborhood or sublocality
        let bestName = results[0].formatted_address;
        for (const res of results) {
          const types = res.types || [];
          if (types.includes("sublocality") || types.includes("neighborhood") || types.includes("point_of_interest")) {
            bestName = res.formatted_address.split(",").slice(0, 2).join(",").trim();
            break;
          }
        }

        placesCache.set(cacheKey, bestName);
        return bestName;
      }
    } catch (_) {}
  }

  // Fallback to coordinates
  const fallback = `Location (${Number(lat).toFixed(3)}, ${Number(lon).toFixed(3)})`;
  placesCache.set(cacheKey, fallback);
  return fallback;
}


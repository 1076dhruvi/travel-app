import axios from "axios";

// In-memory cache for leg routing calculations
const routesCache = new Map();

/**
 * Decodes Google's Encoded Polyline algorithm into a list of [lat, lon] coordinates.
 */
export function decodePolyline(encoded) {
  if (!encoded || typeof encoded !== "string") return [];
  const points = [];
  let index = 0;
  const len = encoded.length;
  let lat = 0;
  let lng = 0;

  while (index < len) {
    let b;
    let shift = 0;
    let result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    points.push([
      Number((lat / 1e5).toFixed(6)),
      Number((lng / 1e5).toFixed(6)),
    ]);
  }
  return points;
}

/**
 * Calculates Haversine distance in kilometers between two points.
 */
export function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Queries Google Routes API v2 (with Google Directions API and Geoapify/OSRM fallback).
 * Returns real distance, duration, mode, transit line, and road-following polyline coordinates.
 */
export async function computeLegRoute(origin, destination) {
  if (!origin?.lat || !origin?.lon || !destination?.lat || !destination?.lon) {
    return null;
  }

  const cacheKey = `${Number(origin.lat).toFixed(4)},${Number(origin.lon).toFixed(4)}->${Number(destination.lat).toFixed(4)},${Number(destination.lon).toFixed(4)}`;
  if (routesCache.has(cacheKey)) {
    return routesCache.get(cacheKey);
  }

  const distKm = haversineDistanceKm(
    Number(origin.lat),
    Number(origin.lon),
    Number(destination.lat),
    Number(destination.lon)
  );

  // Preferred mode heuristic:
  // Short distances (< 1.2 km): walk
  // Medium/long: try transit first, then drive/cab
  const isWalkingDistance = distKm < 1.2;

  const googleApiKey =
    process.env["GOOGLE_ROUTES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  // 1. Try Google Routes API v2
  if (googleApiKey) {
    // Attempt transit first for non-walking distance, or walk for short distance
    const modesToTry = isWalkingDistance
      ? ["WALK", "DRIVE"]
      : ["TRANSIT", "DRIVE", "WALK"];

    for (const travelMode of modesToTry) {
      try {
        const response = await axios.post(
          "https://routes.googleapis.com/directions/v2:computeRoutes",
          {
            origin: {
              location: {
                latLng: {
                  latitude: Number(origin.lat),
                  longitude: Number(origin.lon),
                },
              },
            },
            destination: {
              location: {
                latLng: {
                  latitude: Number(destination.lat),
                  longitude: Number(destination.lon),
                },
              },
            },
            travelMode: travelMode,
            computeAlternativeRoutes: false,
          },
          {
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": googleApiKey,
              "X-Goog-FieldMask":
                "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.transitDetails",
            },
            timeout: 7000,
          }
        );

        const route = response.data?.routes?.[0];
        if (route) {
          const durationSec = parseInt((route.duration || "0s").replace("s", ""), 10) || 300;
          const distanceMeters = route.distanceMeters || Math.round(distKm * 1000);
          const polyline = decodePolyline(route.polyline?.encodedPolyline);

          let finalMode = travelMode.toLowerCase();
          let transitLine = null;

          if (travelMode === "TRANSIT") {
            finalMode = "bus"; // default transit label
            // Extract transit line details from steps
            const steps = route.legs?.[0]?.steps || [];
            for (const step of steps) {
              const td = step.transitDetails;
              if (td) {
                const line = td.transitLine;
                const vehicleType = line?.vehicle?.type || "";
                if (vehicleType.toLowerCase().includes("train") || vehicleType.toLowerCase().includes("rail") || vehicleType.toLowerCase().includes("subway") || vehicleType.toLowerCase().includes("metro")) {
                  finalMode = "train";
                } else {
                  finalMode = "bus";
                }

                const lineName = line?.nameShort || line?.name || td.headsign;
                if (lineName) {
                  transitLine = lineName;
                }
              }
            }

            if (!transitLine) {
              transitLine = "check locally";
            }
          } else if (travelMode === "DRIVE") {
            finalMode = "cab";
          } else if (travelMode === "WALK") {
            finalMode = "walk";
          }

          const result = {
            from: origin.name || "Start",
            to: destination.name || "Destination",
            distance: `${(distanceMeters / 1000).toFixed(1)} km`,
            distanceMeters: distanceMeters,
            duration: `${Math.max(1, Math.round(durationSec / 60))} min`,
            durationMinutes: Math.max(1, Math.round(durationSec / 60)),
            durationSeconds: durationSec,
            mode: finalMode,
            transitLine: transitLine,
            polyline: polyline.length > 0 ? polyline : [
              [Number(origin.lat), Number(origin.lon)],
              [Number(destination.lat), Number(destination.lon)],
            ],
          };

          routesCache.set(cacheKey, result);
          return result;
        }
      } catch (routesErr) {
        // Try next mode or fall back
      }
    }

    // 2. Try Google Directions API legacy
    try {
      const modeParam = isWalkingDistance ? "walking" : "transit";
      const directionsRes = await axios.get(
        "https://maps.googleapis.com/maps/api/directions/json",
        {
          params: {
            origin: `${origin.lat},${origin.lon}`,
            destination: `${destination.lat},${destination.lon}`,
            mode: modeParam,
            key: googleApiKey,
          },
          timeout: 6000,
        }
      );

      const dRoute = directionsRes.data?.routes?.[0];
      if (dRoute && dRoute.legs?.[0]) {
        const leg = dRoute.legs[0];
        const polyline = decodePolyline(dRoute.overview_polyline?.points);

        let finalMode = isWalkingDistance ? "walk" : "bus";
        let transitLine = null;

        const steps = leg.steps || [];
        for (const s of steps) {
          if (s.transit_details) {
            const line = s.transit_details.line;
            const vType = line?.vehicle?.type || "";
            if (vType.toLowerCase().includes("train") || vType.toLowerCase().includes("subway")) {
              finalMode = "train";
            }
            transitLine = line?.short_name || line?.name || "check locally";
          }
        }

        const result = {
          from: origin.name || "Start",
          to: destination.name || "Destination",
          distance: leg.distance?.text || `${(leg.distance?.value / 1000).toFixed(1)} km`,
          distanceMeters: leg.distance?.value || Math.round(distKm * 1000),
          duration: leg.duration?.text || `${Math.round((leg.duration?.value || 300) / 60)} min`,
          durationMinutes: Math.round((leg.duration?.value || 300) / 60),
          durationSeconds: leg.duration?.value || 300,
          mode: finalMode,
          transitLine: transitLine,
          polyline: polyline,
        };

        routesCache.set(cacheKey, result);
        return result;
      }
    } catch (dirErr) {
      // Continue to Geoapify / OSRM fallback
    }
  }

  // 3. Fallback to Geoapify Routing API
  const geoapifyKey = process.env["GEOAPIFY_API_KEY"];
  if (geoapifyKey) {
    try {
      const geoMode = isWalkingDistance ? "walk" : "drive";
      const geoRes = await axios.get("https://api.geoapify.com/v1/routing", {
        params: {
          waypoints: `${origin.lat},${origin.lon}|${destination.lat},${destination.lon}`,
          mode: geoMode,
          apiKey: geoapifyKey,
        },
        timeout: 6000,
      });

      const feature = geoRes.data?.features?.[0];
      if (feature) {
        const { distance, time } = feature.properties;
        const coordinates = feature.geometry?.coordinates?.[0] || [];
        // GeoJSON is [lon, lat], convert to [lat, lon]
        const polyline = coordinates.map((c) => [c[1], c[0]]);

        const finalMode = isWalkingDistance ? "walk" : (distKm > 4 ? "bus" : "cab");

        const result = {
          from: origin.name || "Start",
          to: destination.name || "Destination",
          distance: `${(distance / 1000).toFixed(1)} km`,
          distanceMeters: distance,
          duration: `${Math.max(1, Math.round(time / 60))} min`,
          durationMinutes: Math.max(1, Math.round(time / 60)),
          durationSeconds: time,
          mode: finalMode,
          transitLine: finalMode === "bus" ? "check locally" : null,
          polyline: polyline.length > 0 ? polyline : [
            [Number(origin.lat), Number(origin.lon)],
            [Number(destination.lat), Number(destination.lon)],
          ],
        };

        routesCache.set(cacheKey, result);
        return result;
      }
    } catch (geoErr) {
      // Continue to OSRM fallback
    }
  }

  // 4. Open-source OSRM Fallback (Road-following geometry)
  try {
    const osrmMode = isWalkingDistance ? "foot" : "car";
    const osrmRes = await axios.get(
      `https://router.project-osrm.org/route/v1/${osrmMode}/${origin.lon},${origin.lat};${destination.lon},${destination.lat}?overview=full&geometries=geojson`,
      { timeout: 6000 }
    );

    const route = osrmRes.data?.routes?.[0];
    if (route) {
      const coords = route.geometry?.coordinates || [];
      const polyline = coords.map((c) => [c[1], c[0]]); // [lat, lon]
      const durationSec = Math.round(route.duration);
      const distMeters = Math.round(route.distance);

      const finalMode = isWalkingDistance ? "walk" : (distKm > 5 ? "bus" : "cab");

      const result = {
        from: origin.name || "Start",
        to: destination.name || "Destination",
        distance: `${(distMeters / 1000).toFixed(1)} km`,
        distanceMeters: distMeters,
        duration: `${Math.max(1, Math.round(durationSec / 60))} min`,
        durationMinutes: Math.max(1, Math.round(durationSec / 60)),
        durationSeconds: durationSec,
        mode: finalMode,
        transitLine: finalMode === "bus" ? "check locally" : null,
        polyline: polyline,
      };

      routesCache.set(cacheKey, result);
      return result;
    }
  } catch (osrmErr) {
    // Final basic calculation
  }

  // 5. Final geometric fallback
  const approxSpeedKmH = isWalkingDistance ? 4.5 : 25; // km/h
  const travelMinutes = Math.max(3, Math.round((distKm / approxSpeedKmH) * 60));
  const fallbackResult = {
    from: origin.name || "Start",
    to: destination.name || "Destination",
    distance: `${distKm.toFixed(1)} km`,
    distanceMeters: Math.round(distKm * 1000),
    duration: `${travelMinutes} min`,
    durationMinutes: travelMinutes,
    durationSeconds: travelMinutes * 60,
    mode: isWalkingDistance ? "walk" : "cab",
    transitLine: null,
    polyline: [
      [Number(origin.lat), Number(origin.lon)],
      [Number(destination.lat), Number(destination.lon)],
    ],
  };

  routesCache.set(cacheKey, fallbackResult);
  return fallbackResult;
}

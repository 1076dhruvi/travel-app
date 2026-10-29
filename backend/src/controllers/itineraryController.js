import { generateItineraryPlan } from "../services/geminiService.js";
import { getPlaceDetails, getCityCenter } from "../services/placesService.js";
import { computeLegRoute, haversineDistanceKm } from "../services/routesService.js";
import { orderStopsByShortestPath } from "../services/clusteringOrderingService.js";
import { calculateSchedule } from "../services/scheduleService.js";

export const generateItinerary = async (req, res) => {
  console.log("\n[LOG] Starting End-to-End Itinerary Generation Pipeline...");

  try {
    const {
      destination = "Mumbai",
      days = 2,
      interests = [],
      startPoint = null,
    } = req.body;

    // 1. Resolve destination city center via Places API
    const cityCenter = await getCityCenter(destination);
    const cityCenterLat = cityCenter ? Number(cityCenter.lat) : null;
    const cityCenterLon = cityCenter ? Number(cityCenter.lon) : null;

    // 2. Resolve effective start point (never use stale coordinates)
    let effectiveStart = null;
    if (startPoint && startPoint.lat != null && startPoint.lon != null && !isNaN(Number(startPoint.lat)) && !isNaN(Number(startPoint.lon))) {
      effectiveStart = {
        name: startPoint.name || "Start Location",
        lat: Number(startPoint.lat),
        lon: Number(startPoint.lon),
        departureTime: "09:00",
      };
    } else if (cityCenterLat != null && cityCenterLon != null) {
      effectiveStart = {
        name: `${destination} City Center`,
        lat: cityCenterLat,
        lon: cityCenterLon,
        departureTime: "09:00",
      };
    }

    // 3. Request Gemini for place names & clustering (coordinates NOT trusted from Gemini)
    console.log(`[LOG] Requesting Gemini day attractions for ${destination} (${days} days)...`);
    const dayClusters = await generateItineraryPlan(destination, days, interests);

    const enrichedDays = [];

    // 4. Process each day
    for (let dayIndex = 0; dayIndex < dayClusters.length; dayIndex++) {
      const dayData = dayClusters[dayIndex];
      const dayNum = dayData.day || dayIndex + 1;
      const rawAttractions = dayData.attractions || [];

      console.log(`[LOG] Processing Day ${dayNum} (${rawAttractions.length} attractions)...`);

      // 4a. Geocode each place strictly via Places API (Text Search)
      // Discard any Gemini coordinates; apply 50 km sanity check from city center
      const verifiedPlaces = [];
      for (const attr of rawAttractions) {
        if (!attr.name) continue;

        try {
          const placeInfo = await getPlaceDetails(attr.name, destination);
          if (placeInfo && placeInfo.lat != null && placeInfo.lon != null) {
            const pLat = Number(placeInfo.lat);
            const pLon = Number(placeInfo.lon);

            // Sanity check: Drop stops >50 km from destination city centre
            if (cityCenterLat != null && cityCenterLon != null) {
              const distFromCenter = haversineDistanceKm(cityCenterLat, cityCenterLon, pLat, pLon);
              if (distFromCenter > 50) {
                console.warn(`[SANITY CHECK] Dropping ${attr.name}: ${distFromCenter.toFixed(1)} km from ${destination} city center (> 50 km)`);
                continue;
              }
            }

            verifiedPlaces.push({
              name: placeInfo.name || attr.name,
              description: attr.description || "",
              bestTime: attr.bestTime || "Morning",
              openingHours: placeInfo.openingHours || "check locally",
              lat: pLat,
              lon: pLon,
              dayNumber: dayNum,
              day: `Day ${dayNum}`,
            });
          } else {
            console.warn(`[SANITY CHECK] Dropping ${attr.name}: Could not verify coordinates via Places API`);
          }
        } catch (pErr) {
          console.warn(`Places API lookup error for ${attr.name}:`, pErr.message);
        }
      }

      // If effectiveStart wasn't set, fallback to first verified place
      if (!effectiveStart && verifiedPlaces.length > 0) {
        effectiveStart = {
          name: `${verifiedPlaces[0].name} (Start)`,
          lat: verifiedPlaces[0].lat,
          lon: verifiedPlaces[0].lon,
          departureTime: "09:00",
        };
      }

      // 4b. Re-order stops by shortest path from effectiveStart
      const orderedStops = orderStopsByShortestPath(effectiveStart, verifiedPlaces);
      orderedStops.forEach((stop, idx) => {
        stop.stopNumber = idx + 1;
      });

      // 4c. Compute real legs using Google Routes API
      // Leg 0: startPoint -> stop 1
      // Leg i: stop i-1 -> stop i (NEVER from start point)
      const legs = [];
      let totalMeters = 0;
      let totalSeconds = 0;

      for (let i = 0; i < orderedStops.length; i++) {
        const fromPlace = i === 0 ? effectiveStart : orderedStops[i - 1];
        const toPlace = orderedStops[i];

        if (fromPlace && toPlace) {
          try {
            const leg = await computeLegRoute(fromPlace, toPlace);
            if (leg) {
              legs.push(leg);
              totalMeters += leg.distanceMeters || 0;
              totalSeconds += leg.durationSeconds || 0;
            }
          } catch (legErr) {
            console.warn(`Leg computation failed for stop ${i + 1}:`, legErr.message);
          }
        }
      }

      // 4d. Calculate schedule conforming to opening hours
      calculateSchedule(orderedStops, legs, "09:00");

      // 4e. Day Totals
      const totalKm = (totalMeters / 1000).toFixed(1);
      const totalTransitMins = Math.round(totalSeconds / 60);

      enrichedDays.push({
        day: dayNum,
        theme: dayData.theme || `Day ${dayNum} Sightseeing`,
        area: dayData.area || "",
        totalStops: orderedStops.length,
        totalKm: `${totalKm} km`,
        totalTransitMinutes: totalTransitMins,
        totalTransitTime: `${totalTransitMins} min`,
        startPoint: effectiveStart,
        attractions: orderedStops,
        legs: legs,
      });
    }

    console.log("[SUCCESS] Complete Itinerary Generated Successfully with Multi-mode Legs!");

    return res.json({
      success: true,
      destination: destination,
      days: days,
      startPoint: effectiveStart,
      itinerary: enrichedDays,
    });
  } catch (error) {
    console.error("[ITINERARY GENERATION ERROR]:", error.message);
    return res.status(500).json({
      success: false,
      error: error.message || "Failed to generate refined itinerary",
    });
  }
};
import { generateItineraryPlan } from "../services/geminiService.js";
import { getPlaceDetails, getCityCenter } from "../services/placesService.js";
import { computeLegRoute, haversineDistanceKm } from "../services/routesService.js";
import { orderStopsByShortestPath } from "../services/clusteringOrderingService.js";
import { calculateSchedule } from "../services/scheduleService.js";
import { clusterPlacesByProximity } from "../services/clusterService.js";

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

    // 3. Request Gemini for place names & attraction selection
    console.log(`[LOG] Requesting Gemini day attractions for ${destination} (${days} days)...`);
    const geminiDayPlans = await generateItineraryPlan(destination, days, interests);

    // 4. Resolve each place through Places Text Search, dedupe by placeId across ALL days
    console.log(`[LOG] Resolving attractions with Places API Text Search & deduping trip-wide...`);
    const tripUsedPlaceIds = new Set();
    const tripUsedNames = new Set();
    const allVerifiedPlaces = [];

    // Collect all raw attractions across all Gemini day groups
    for (const dayData of geminiDayPlans) {
      const attractions = dayData.attractions || [];
      for (const attr of attractions) {
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

            // Deduplicate across the ENTIRE trip by placeId and normalized name
            const placeIdKey = placeInfo.placeId || `${pLat.toFixed(4)},${pLon.toFixed(4)}`;
            const normName = (placeInfo.name || attr.name).toLowerCase().trim();

            if (tripUsedPlaceIds.has(placeIdKey) || tripUsedNames.has(normName)) {
              console.log(`[DEDUPE] Dropping duplicate place across trip: ${placeInfo.name || attr.name} (${placeIdKey})`);
              continue;
            }

            tripUsedPlaceIds.add(placeIdKey);
            tripUsedNames.add(normName);

            allVerifiedPlaces.push({
              placeId: placeIdKey,
              name: placeInfo.name || attr.name,
              description: attr.description || "",
              bestTime: attr.bestTime || "Morning",
              openingHours: placeInfo.openingHours || "check locally",
              lat: pLat,
              lon: pLon,
              preferredTheme: dayData.theme || "",
              preferredArea: dayData.area || "",
            });
          } else {
            console.warn(`[SANITY CHECK] Dropping ${attr.name}: Could not verify coordinates via Places API`);
          }
        } catch (pErr) {
          console.warn(`Places API lookup error for ${attr.name}:`, pErr.message);
        }
      }
    }

    console.log(`[LOG] Successfully verified ${allVerifiedPlaces.length} unique attractions for ${days} days.`);

    // If effectiveStart wasn't set, fallback to first verified place
    if (!effectiveStart && allVerifiedPlaces.length > 0) {
      effectiveStart = {
        name: `${allVerifiedPlaces[0].name} (Start)`,
        lat: allVerifiedPlaces[0].lat,
        lon: allVerifiedPlaces[0].lon,
        departureTime: "09:00",
      };
    }

    // 5. Cluster by lat/lng (distance threshold ~5 km).
    // Each day = one cluster, each place belongs to exactly one cluster.
    // Museum goes only in the South Mumbai (Fort/Kala Ghoda/Colaba) day.
    const clusters = clusterPlacesByProximity(allVerifiedPlaces, days, destination);

    const enrichedDays = [];

    // 6. Process each clustered day
    for (let dayIndex = 0; dayIndex < days; dayIndex++) {
      const dayNum = dayIndex + 1;
      const clusterPlaces = clusters[dayIndex] || [];
      const geminiDayMeta = geminiDayPlans[dayIndex] || {};

      console.log(`[LOG] Processing Clustered Day ${dayNum} (${clusterPlaces.length} attractions)...`);

      // Set day label on each place
      const dayPlaces = clusterPlaces.map((p) => ({
        ...p,
        dayNumber: dayNum,
        day: `Day ${dayNum}`,
      }));

      // 6a. Re-order stops by shortest path from effectiveStart
      const orderedStops = orderStopsByShortestPath(effectiveStart, dayPlaces);
      orderedStops.forEach((stop, idx) => {
        stop.stopNumber = idx + 1;
      });

      // 6b. Compute real legs using Google Routes API
      // Leg 0: startPoint -> stop 1
      // Leg i: stop i-1 -> stop i
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

      // 6c. Calculate schedule conforming to opening hours
      calculateSchedule(orderedStops, legs, "09:00");

      // 6d. Day Totals
      const totalKm = (totalMeters / 1000).toFixed(1);
      const totalTransitMins = Math.round(totalSeconds / 60);

      // Determine area name from places or fallback to Gemini theme
      const areaName = geminiDayMeta.area || (orderedStops.length > 0 ? orderedStops[0].name.split(",")[0] : `Cluster ${dayNum}`);

      enrichedDays.push({
        day: dayNum,
        theme: geminiDayMeta.theme || `Day ${dayNum} Sightseeing`,
        area: areaName,
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
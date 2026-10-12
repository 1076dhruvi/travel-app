import { generateItineraryPlan } from "../services/geminiService.js";
import { getPlaceDetails } from "../services/placesService.js";
import { computeLegRoute } from "../services/routesService.js";
import { orderStopsByShortestPath } from "../services/clusteringOrderingService.js";
import { calculateSchedule } from "../services/scheduleService.js";
import { geocodePlace } from "../services/geocodeService.js";

export const generateItinerary = async (req, res) => {
  console.log("\n[LOG] Starting End-to-End Itinerary Generation Pipeline...");

  try {
    const {
      destination = "Kochi",
      days = 2,
      interests = [],
      startPoint = null,
    } = req.body;

    // 1. Resolve effective start point (user location or manual entry)
    let effectiveStart = null;
    if (startPoint && startPoint.lat != null && startPoint.lon != null) {
      effectiveStart = {
        name: startPoint.name || "Start Location",
        lat: Number(startPoint.lat),
        lon: Number(startPoint.lon),
        departureTime: "09:00",
      };
    } else {
      // Fallback: Geocode destination city center
      try {
        const cityCenter = await geocodePlace(destination);
        if (cityCenter) {
          effectiveStart = {
            name: `${destination} City Center`,
            lat: Number(cityCenter.lat),
            lon: Number(cityCenter.lng ?? cityCenter.lon),
            departureTime: "09:00",
          };
        }
      } catch (_) {}
    }

    // 2. Gemini selects attractions and clusters by proximity (strict JSON)
    console.log(`[LOG] Requesting Gemini day clustering for ${destination} (${days} days)...`);
    const dayClusters = await generateItineraryPlan(destination, days, interests);

    const enrichedDays = [];

    // 3. Process each day: Places API for hours, shortest path ordering, Routes API for legs
    for (let dayIndex = 0; dayIndex < dayClusters.length; dayIndex++) {
      const dayData = dayClusters[dayIndex];
      const dayNum = dayData.day || dayIndex + 1;
      const rawAttractions = dayData.attractions || [];

      console.log(`[LOG] Processing Day ${dayNum} (${rawAttractions.length} attractions)...`);

      // 3a. Enrich places with Google Places API for real opening hours & verified coordinates
      const verifiedPlaces = [];
      for (const attr of rawAttractions) {
        let lat = attr.lat != null ? Number(attr.lat) : null;
        let lon = attr.lon != null ? Number(attr.lon) : null;
        let openingHours = "check locally";
        let resolvedName = attr.name;

        try {
          const placeInfo = await getPlaceDetails(attr.name, destination);
          if (placeInfo) {
            if (placeInfo.lat != null && placeInfo.lon != null) {
              lat = Number(placeInfo.lat);
              lon = Number(placeInfo.lon);
            }
            if (placeInfo.openingHours) {
              openingHours = placeInfo.openingHours;
            }
            if (placeInfo.name) {
              resolvedName = placeInfo.name;
            }
          }
        } catch (pErr) {
          console.warn(`Places API lookup warning for ${attr.name}:`, pErr.message);
        }

        // If coordinates still missing, use approximate destination coordinates
        if (lat == null || lon == null) {
          lat = effectiveStart ? effectiveStart.lat : 0;
          lon = effectiveStart ? effectiveStart.lon : 0;
        }

        verifiedPlaces.push({
          name: resolvedName,
          description: attr.description || "",
          bestTime: attr.bestTime || "Morning",
          openingHours: openingHours,
          lat: lat,
          lon: lon,
          dayNumber: dayNum,
          day: `Day ${dayNum}`,
        });
      }

      // If effectiveStart wasn't set, use first place
      if (!effectiveStart && verifiedPlaces.length > 0) {
        effectiveStart = {
          name: `${verifiedPlaces[0].name} (Start)`,
          lat: verifiedPlaces[0].lat,
          lon: verifiedPlaces[0].lon,
          departureTime: "09:00",
        };
      }

      // 3b. Order stops by shortest path from start point
      const orderedStops = orderStopsByShortestPath(effectiveStart, verifiedPlaces);
      orderedStops.forEach((stop, idx) => {
        stop.stopNumber = idx + 1;
      });

      // 3c. Compute real legs using Google Routes API
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
            console.warn(`Leg computation failed:`, legErr.message);
          }
        }
      }

      // 3d. Calculate arrival/leave times fitting opening hours
      calculateSchedule(orderedStops, legs, "09:00");

      // 3e. Day Totals
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

    console.log("[SUCCESS] Complete Itinerary Generated Successfully!");

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
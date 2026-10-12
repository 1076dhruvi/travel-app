import { computeLegRoute } from "../services/routesService.js";
import { orderStopsByShortestPath } from "../services/clusteringOrderingService.js";
import { getPlaceDetails } from "../services/placesService.js";

export const optimizeItinerary = async (req, res) => {
  try {
    const { city, places, startPoint } = req.body;

    if (!places || !Array.isArray(places) || places.length === 0) {
      return res.json({ success: true, coordinates: [], routes: [] });
    }

    const coordinates = [];

    for (const place of places) {
      if (typeof place === "object" && place !== null) {
        const lat = place.lat ?? place.latitude;
        const lng = place.lng ?? place.lon ?? place.longitude;
        if (lat != null && lng != null && !isNaN(Number(lat)) && !isNaN(Number(lng))) {
          coordinates.push({
            name: place.name || "",
            lat: Number(lat),
            lon: Number(lng),
          });
          continue;
        }
      }

      const placeName = typeof place === "string" ? place : place?.name || "";
      if (!placeName) continue;

      const placeInfo = await getPlaceDetails(placeName, city);
      if (placeInfo && placeInfo.lat != null && placeInfo.lon != null) {
        coordinates.push({
          name: placeInfo.name,
          lat: Number(placeInfo.lat),
          lon: Number(placeInfo.lon),
        });
      }
    }

    // Order stops by shortest path from startPoint if provided
    let orderedCoords = coordinates;
    if (startPoint && startPoint.lat != null && startPoint.lon != null) {
      orderedCoords = orderStopsByShortestPath(startPoint, coordinates);
    }

    const routes = [];
    const allPoints = startPoint ? [startPoint, ...orderedCoords] : orderedCoords;

    for (let i = 0; i < allPoints.length - 1; i++) {
      try {
        const route = await computeLegRoute(allPoints[i], allPoints[i + 1]);
        if (route) {
          routes.push(route);
        }
      } catch (routeErr) {
        console.warn(`Routing failed between points:`, routeErr.message);
      }
    }

    res.json({
      success: true,
      coordinates: orderedCoords,
      routes: routes,
    });
  } catch (error) {
    console.error("OPTIMIZE ERROR:", error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};
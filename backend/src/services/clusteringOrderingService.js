import { haversineDistanceKm } from "./routesService.js";

/**
 * Orders a day's attraction stops by shortest path starting from the user's start point.
 * Uses greedy nearest-neighbour path to guarantee minimal transit progression.
 *
 * @param {Object} startPoint - { name: string, lat: number, lon: number }
 * @param {Array<Object>} places - Array of attractions with lat and lon
 * @returns {Array<Object>} Ordered array of places
 */
export function orderStopsByShortestPath(startPoint, places) {
  if (!places || places.length <= 1) {
    return places || [];
  }

  const unvisited = [...places];
  const ordered = [];

  let current = {
    lat: Number(startPoint?.lat ?? places[0].lat),
    lon: Number(startPoint?.lon ?? places[0].lon),
  };

  while (unvisited.length > 0) {
    let closestIndex = 0;
    let minDistance = Infinity;

    for (let i = 0; i < unvisited.length; i++) {
      const place = unvisited[i];
      const pLat = Number(place.lat);
      const pLon = Number(place.lon);

      if (isNaN(pLat) || isNaN(pLon)) {
        closestIndex = i;
        break;
      }

      const dist = haversineDistanceKm(current.lat, current.lon, pLat, pLon);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    const nextStop = unvisited.splice(closestIndex, 1)[0];
    ordered.push(nextStop);
    current = {
      lat: Number(nextStop.lat),
      lon: Number(nextStop.lon),
    };
  }

  return ordered;
}

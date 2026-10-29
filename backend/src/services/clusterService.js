import { haversineDistanceKm } from "./routesService.js";

/**
 * Checks if a place is the Chhatrapati Shivaji Maharaj Vastu Sangrahalaya
 */
export function isMuseum(placeName) {
  if (!placeName) return false;
  const lower = placeName.toLowerCase();
  return (
    lower.includes("vastu sangrahalaya") ||
    lower.includes("prince of wales museum") ||
    (lower.includes("chhatrapati shivaji") && lower.includes("museum"))
  );
}

/**
 * Checks if coordinates correspond to South Mumbai (Fort, Colaba, Marine Drive area)
 */
export function isSouthMumbaiCoords(lat, lon) {
  // South Mumbai lies below latitude ~18.965 and longitude between 72.80 and 72.85
  return lat <= 18.965 && lon >= 72.80 && lon <= 72.86;
}

/**
 * Clusters an array of verified places into `clusterCount` distinct day clusters
 * based on geographic proximity (~5 km distance threshold).
 *
 * Rules:
 * - Each day = one cluster.
 * - Each place belongs to exactly ONE cluster.
 * - If destination is Mumbai, any appearance of the museum goes ONLY in the South Mumbai cluster.
 *
 * @param {Array<Object>} places - Unique verified place objects with lat and lon
 * @param {number} clusterCount - Number of days / clusters
 * @param {string} destination - Destination city name
 * @returns {Array<Array<Object>>} Array of clusters, length = clusterCount
 */
export function clusterPlacesByProximity(places, clusterCount = 2, destination = "") {
  if (!places || places.length === 0) {
    return Array.from({ length: clusterCount }, () => []);
  }

  const k = Math.min(clusterCount, Math.max(1, places.length));
  const isMumbai = destination.toLowerCase().includes("mumbai");

  // Separate museum if in Mumbai to ensure it strictly lands in South Mumbai
  let museumPlace = null;
  const regularPlaces = [];

  for (const p of places) {
    if (isMumbai && isMuseum(p.name)) {
      if (!museumPlace) {
        museumPlace = p;
      }
      // If duplicate museum exists, drop it
    } else {
      regularPlaces.push(p);
    }
  }

  // 1. Initialize cluster centroids
  // Use k-means++ style seeding to pick geographically separated seeds (~5km+ apart)
  const allPool = museumPlace ? [museumPlace, ...regularPlaces] : [...regularPlaces];
  const centroids = [];

  // If Mumbai and museum exists, seed South Mumbai centroid first (around 18.927, 72.833)
  if (isMumbai && museumPlace) {
    centroids.push({ lat: Number(museumPlace.lat), lon: Number(museumPlace.lon), isSouthMumbai: true });
  } else {
    centroids.push({ lat: Number(allPool[0].lat), lon: Number(allPool[0].lon) });
  }

  while (centroids.length < k && allPool.length > centroids.length) {
    // Pick the place that is furthest from existing centroids
    let bestCandidate = null;
    let maxDist = -1;

    for (const p of allPool) {
      const pLat = Number(p.lat);
      const pLon = Number(p.lon);

      // Min distance to any existing centroid
      let minDistToCentroid = Infinity;
      for (const c of centroids) {
        const d = haversineDistanceKm(pLat, pLon, c.lat, c.lon);
        if (d < minDistToCentroid) {
          minDistToCentroid = d;
        }
      }

      if (minDistToCentroid > maxDist) {
        maxDist = minDistToCentroid;
        bestCandidate = { lat: pLat, lon: pLon };
      }
    }

    if (bestCandidate) {
      centroids.push(bestCandidate);
    } else {
      break;
    }
  }

  // Fill up if fewer centroids than k
  while (centroids.length < k) {
    centroids.push({ ...centroids[0] });
  }

  // Identify which centroid is South Mumbai (if Mumbai)
  let southMumbaiClusterIdx = 0;
  if (isMumbai) {
    let minLat = Infinity;
    for (let i = 0; i < centroids.length; i++) {
      if (centroids[i].lat < minLat) {
        minLat = centroids[i].lat;
        southMumbaiClusterIdx = i;
      }
    }
  }

  // 2. K-means assignment iterations (max 10 iterations)
  let clusters = Array.from({ length: k }, () => []);

  for (let iter = 0; iter < 10; iter++) {
    clusters = Array.from({ length: k }, () => []);

    // Museum is anchored to South Mumbai
    if (museumPlace) {
      clusters[southMumbaiClusterIdx].push(museumPlace);
    }

    // Assign each regular place to nearest cluster centroid
    for (const p of regularPlaces) {
      const pLat = Number(p.lat);
      const pLon = Number(p.lon);

      let bestIdx = 0;
      let minDistance = Infinity;

      for (let i = 0; i < centroids.length; i++) {
        const dist = haversineDistanceKm(pLat, pLon, centroids[i].lat, centroids[i].lon);
        if (dist < minDistance) {
          minDistance = dist;
          bestIdx = i;
        }
      }

      clusters[bestIdx].push(p);
    }

    // Recompute centroids
    let maxShift = 0;
    for (let i = 0; i < k; i++) {
      if (clusters[i].length === 0) continue;

      let sumLat = 0;
      let sumLon = 0;
      for (const p of clusters[i]) {
        sumLat += Number(p.lat);
        sumLon += Number(p.lon);
      }
      const newLat = sumLat / clusters[i].length;
      const newLon = sumLon / clusters[i].length;

      const shift = haversineDistanceKm(centroids[i].lat, centroids[i].lon, newLat, newLon);
      if (shift > maxShift) maxShift = shift;

      centroids[i].lat = newLat;
      centroids[i].lon = newLon;
    }

    if (maxShift < 0.2) break; // Converged within 200m
  }

  // 3. Balance empty clusters if any cluster has 0 places while another has >4
  for (let i = 0; i < k; i++) {
    if (clusters[i].length === 0) {
      // Find largest cluster
      let maxIdx = 0;
      for (let j = 0; j < k; j++) {
        if (clusters[j].length > clusters[maxIdx].length) {
          maxIdx = j;
        }
      }

      if (clusters[maxIdx].length > 1) {
        // Take a place furthest from maxIdx centroid (but never the museum if South Mumbai)
        let candidateIdx = -1;
        let maxDist = -1;

        for (let pIdx = 0; pIdx < clusters[maxIdx].length; pIdx++) {
          const item = clusters[maxIdx][pIdx];
          if (museumPlace && item === museumPlace) continue;

          const d = haversineDistanceKm(
            centroids[maxIdx].lat,
            centroids[maxIdx].lon,
            Number(item.lat),
            Number(item.lon)
          );
          if (d > maxDist) {
            maxDist = d;
            candidateIdx = pIdx;
          }
        }

        if (candidateIdx >= 0) {
          const moved = clusters[maxIdx].splice(candidateIdx, 1)[0];
          clusters[i].push(moved);
        }
      }
    }
  }

  // Ensure result has exact length `clusterCount`
  while (clusters.length < clusterCount) {
    clusters.push([]);
  }

  return clusters;
}

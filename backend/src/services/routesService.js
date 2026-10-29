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

import { calculateAutoFare, calculateCabFare } from "../config/fareConfig.js";

function formatDepartureTime(isoString) {
  if (!isoString) return null;
  try {
    const d = new Date(isoString);
    if (!isNaN(d.getTime())) {
      return d.toLocaleTimeString("en-IN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: true,
      });
    }
  } catch (_) {}
  return isoString;
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

  const googleApiKey =
    process.env["GOOGLE_ROUTES_API_KEY"] ||
    process.env["GOOGLE_MAPS_API_KEY"] ||
    process.env["GOOGLE_API_KEY"] ||
    process.env["GEMINI_API_KEY"];

  const options = [];
  let driveRouteData = null;

  if (googleApiKey) {
    const modes = ["DRIVE", "TRANSIT", "WALK"];

    for (const travelMode of modes) {
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
            computeAlternativeRoutes: travelMode !== "WALK",
          },
          {
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": googleApiKey,
              "X-Goog-FieldMask":
                "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.transitDetails,routes.legs.steps.navigationInstruction,routes.legs.steps.travelMode,routes.legs.steps.localizedValues,routes.travelAdvisory.transitFare,routes.description",
            },
            timeout: 6000,
          }
        );

        const routesList = response.data?.routes || [];
        for (const route of routesList) {
          const durationSec = parseInt((route.duration || "0s").replace("s", ""), 10) || 300;
          const distanceMeters = route.distanceMeters || Math.round(distKm * 1000);
          const polyline = decodePolyline(route.polyline?.encodedPolyline);
          const distKmVal = distanceMeters / 1000;
          const durationMins = Math.max(1, Math.round(durationSec / 60));

          if (travelMode === "DRIVE") {
            driveRouteData = {
              durationSec,
              durationMins,
              distanceMeters,
              distKmVal,
              polyline,
            };

            const autoFare = calculateAutoFare(distKmVal, durationMins);
            const cabFare = calculateCabFare(distKmVal, durationMins);

            options.push({
              mode: "auto",
              title: "Auto",
              duration: `${durationMins} min`,
              durationMinutes: durationMins,
              durationSeconds: durationSec,
              distance: `${distKmVal.toFixed(1)} km`,
              distanceMeters: distanceMeters,
              cost: autoFare.label,
              polyline: polyline.length > 0 ? polyline : [
                [Number(origin.lat), Number(origin.lon)],
                [Number(destination.lat), Number(destination.lon)],
              ],
              steps: [
                {
                  type: "drive",
                  instruction: `Auto-rickshaw ride to ${destination.name || "destination"} (${distKmVal.toFixed(1)} km)`,
                  duration: `${durationMins} min`,
                  distance: `${distKmVal.toFixed(1)} km`,
                },
              ],
            });

            options.push({
              mode: "cab",
              title: "Cab",
              duration: `${durationMins} min`,
              durationMinutes: durationMins,
              durationSeconds: durationSec,
              distance: `${distKmVal.toFixed(1)} km`,
              distanceMeters: distanceMeters,
              cost: cabFare.label,
              polyline: polyline.length > 0 ? polyline : [
                [Number(origin.lat), Number(origin.lon)],
                [Number(destination.lat), Number(destination.lon)],
              ],
              steps: [
                {
                  type: "drive",
                  instruction: `Cab / Taxi ride to ${destination.name || "destination"} (${distKmVal.toFixed(1)} km)`,
                  duration: `${durationMins} min`,
                  distance: `${distKmVal.toFixed(1)} km`,
                },
              ],
            });
          } else if (travelMode === "TRANSIT") {
            let transitLine = null;
            let vehicleType = "bus";
            let boardingStop = null;
            let alightingStop = null;
            let stopCount = 0;
            let departureTime = null;
            const detailedSteps = [];

            const steps = route.legs?.[0]?.steps || [];
            for (const step of steps) {
              const td = step.transitDetails;
              if (td) {
                const line = td.transitLine;
                const vType = (line?.vehicle?.type || "").toLowerCase();
                if (vType.includes("train") || vType.includes("rail") || vType.includes("subway") || vType.includes("metro")) {
                  vehicleType = "train";
                } else {
                  vehicleType = "bus";
                }

                const shortName = line?.nameShort || line?.name || td.headsign || "";
                if (shortName) {
                  if (vehicleType === "bus" && !shortName.toLowerCase().startsWith("bus")) {
                    transitLine = `Bus ${shortName}`;
                  } else if (vehicleType === "train" && !shortName.toLowerCase().includes("line") && !shortName.toLowerCase().includes("metro")) {
                    transitLine = `${shortName} Line`;
                  } else {
                    transitLine = shortName;
                  }
                }

                boardingStop = td.stopDetails?.departureStop?.name || boardingStop;
                alightingStop = td.stopDetails?.arrivalStop?.name || alightingStop;
                stopCount += td.stopCount || 1;
                departureTime = formatDepartureTime(
                  td.stopDetails?.departureTime ||
                  step.localizedValues?.departureTime?.time?.text
                ) || departureTime;

                detailedSteps.push({
                  type: "transit",
                  instruction: `Board ${transitLine || "transit"} at ${boardingStop || "stop"} towards ${td.headsign || alightingStop || "destination"} (${td.stopCount || 1} stops)`,
                  lineName: transitLine,
                  boardingStop: boardingStop,
                  alightingStop: alightingStop,
                  stopCount: td.stopCount || 1,
                  departureTime: departureTime,
                  duration: step.localizedValues?.staticDuration?.text || `${Math.round(durationSec / 60)} min`,
                });

                if (alightingStop) {
                  detailedSteps.push({
                    type: "transit",
                    instruction: `Get off at ${alightingStop}`,
                    boardingStop: boardingStop,
                    alightingStop: alightingStop,
                  });
                }
              } else if (step.travelMode === "WALK") {
                detailedSteps.push({
                  type: "walk",
                  instruction: `Walk ${step.localizedValues?.distance?.text || "to next stop"} (${step.localizedValues?.staticDuration?.text || "few mins"})`,
                  duration: step.localizedValues?.staticDuration?.text || "2 min",
                  distance: step.localizedValues?.distance?.text || "",
                });
              }
            }

            if (!transitLine) {
              transitLine = "check locally";
            }

            // Fare: only if the API returns one, otherwise "check locally"
            let fareCost = "check locally";
            if (route.travelAdvisory?.transitFare?.units != null) {
              fareCost = `₹${route.travelAdvisory.transitFare.units}`;
            }

            options.push({
              mode: vehicleType,
              title: transitLine,
              duration: `${durationMins} min`,
              durationMinutes: durationMins,
              durationSeconds: durationSec,
              distance: `${distKmVal.toFixed(1)} km`,
              distanceMeters: distanceMeters,
              cost: fareCost,
              transitLine: transitLine,
              boardingStop: boardingStop,
              alightingStop: alightingStop,
              stopCount: stopCount > 0 ? stopCount : null,
              departureTime: departureTime,
              polyline: polyline.length > 0 ? polyline : [
                [Number(origin.lat), Number(origin.lon)],
                [Number(destination.lat), Number(destination.lon)],
              ],
              steps: detailedSteps.length > 0 ? detailedSteps : [
                {
                  type: "transit",
                  instruction: `Take ${transitLine} from ${boardingStop || origin.name || "stop"} to ${alightingStop || destination.name || "destination"}`,
                  lineName: transitLine,
                  boardingStop: boardingStop,
                  alightingStop: alightingStop,
                  stopCount: stopCount > 0 ? stopCount : 3,
                  departureTime: departureTime,
                },
              ],
            });
          } else if (travelMode === "WALK") {
            options.push({
              mode: "walk",
              title: "Walk",
              duration: `${durationMins} min`,
              durationMinutes: durationMins,
              durationSeconds: durationSec,
              distance: `${distKmVal.toFixed(1)} km`,
              distanceMeters: distanceMeters,
              cost: "Free",
              polyline: polyline.length > 0 ? polyline : [
                [Number(origin.lat), Number(origin.lon)],
                [Number(destination.lat), Number(destination.lon)],
              ],
              steps: [
                {
                  type: "walk",
                  instruction: `Walk to ${destination.name || "destination"} (${distKmVal.toFixed(1)} km)`,
                  duration: `${durationMins} min`,
                  distance: `${distKmVal.toFixed(1)} km`,
                },
              ],
            });
          }
        }
      } catch (_) {}
    }
  }

  // Ensure Transit option exists; if no transit data from API, show "check locally" instead of hiding it
  const hasTransit = options.some((o) => o.mode === "bus" || o.mode === "train");
  if (!hasTransit) {
    const transitMins = Math.max(8, Math.round(distKm * 3.5 + 5));
    options.push({
      mode: "bus",
      title: "Transit",
      duration: `${transitMins} min`,
      durationMinutes: transitMins,
      durationSeconds: transitMins * 60,
      distance: `${distKm.toFixed(1)} km`,
      distanceMeters: Math.round(distKm * 1000),
      cost: "check locally",
      transitLine: "check locally",
      boardingStop: null,
      alightingStop: null,
      stopCount: null,
      departureTime: null,
      polyline: [
        [Number(origin.lat), Number(origin.lon)],
        [Number(destination.lat), Number(destination.lon)],
      ],
      steps: [
        {
          type: "transit",
          instruction: `Local bus/transit to ${destination.name || "destination"} (check locally)`,
          lineName: "check locally",
        },
      ],
    });
  }

  // Ensure Auto and Cab options exist (fallback via OSRM if DRIVE wasn't returned by Google)
  const hasAuto = options.some((o) => o.mode === "auto");
  const hasCab = options.some((o) => o.mode === "cab");

  if (!hasAuto || !hasCab) {
    let driveSec = Math.max(120, Math.round(distKm * 180));
    let driveMeters = Math.round(distKm * 1000);
    let drivePolyline = [
      [Number(origin.lat), Number(origin.lon)],
      [Number(destination.lat), Number(destination.lon)],
    ];

    try {
      const osrmCar = await axios.get(
        `https://router.project-osrm.org/route/v1/car/${origin.lon},${origin.lat};${destination.lon},${destination.lat}?overview=full&geometries=geojson`,
        { timeout: 4000 }
      );
      const carRoute = osrmCar.data?.routes?.[0];
      if (carRoute) {
        driveMeters = Math.round(carRoute.distance);
        driveSec = Math.round(carRoute.duration);
        drivePolyline = (carRoute.geometry?.coordinates || []).map((c) => [c[1], c[0]]);
      }
    } catch (_) {}

    const carKm = driveMeters / 1000;
    const carMins = Math.max(1, Math.round(driveSec / 60));
    const autoFare = calculateAutoFare(carKm, carMins);
    const cabFare = calculateCabFare(carKm, carMins);

    if (!hasAuto) {
      options.push({
        mode: "auto",
        title: "Auto",
        duration: `${carMins} min`,
        durationMinutes: carMins,
        durationSeconds: driveSec,
        distance: `${carKm.toFixed(1)} km`,
        distanceMeters: driveMeters,
        cost: autoFare.label,
        polyline: drivePolyline,
        steps: [
          {
            type: "drive",
            instruction: `Auto-rickshaw via road (${carKm.toFixed(1)} km)`,
            duration: `${carMins} min`,
            distance: `${carKm.toFixed(1)} km`,
          },
        ],
      });
    }

    if (!hasCab) {
      options.push({
        mode: "cab",
        title: "Cab",
        duration: `${carMins} min`,
        durationMinutes: carMins,
        durationSeconds: driveSec,
        distance: `${carKm.toFixed(1)} km`,
        distanceMeters: driveMeters,
        cost: cabFare.label,
        polyline: drivePolyline,
        steps: [
          {
            type: "drive",
            instruction: `Drive or cab via road (${carKm.toFixed(1)} km)`,
            duration: `${carMins} min`,
            distance: `${carKm.toFixed(1)} km`,
          },
        ],
      });
    }
  }

  // Ensure Walk option exists
  const hasWalk = options.some((o) => o.mode === "walk");
  if (!hasWalk) {
    const walkMins = Math.max(2, Math.round((distKm / 4.5) * 60));
    options.push({
      mode: "walk",
      title: "Walk",
      duration: `${walkMins} min`,
      durationMinutes: walkMins,
      durationSeconds: walkMins * 60,
      distance: `${distKm.toFixed(1)} km`,
      distanceMeters: Math.round(distKm * 1000),
      cost: "Free",
      polyline: [
        [Number(origin.lat), Number(origin.lon)],
        [Number(destination.lat), Number(destination.lon)],
      ],
      steps: [
        {
          type: "walk",
          instruction: `Walk to ${destination.name || "destination"} (${distKm.toFixed(1)} km)`,
          duration: `${walkMins} min`,
          distance: `${distKm.toFixed(1)} km`,
        },
      ],
    });
  }

  // Deduplicate options if any identical modes exist with duplicate titles
  const uniqueOptions = [];
  const seenKeys = new Set();
  for (const opt of options) {
    const key = `${opt.mode}_${opt.title}_${opt.cost}`;
    if (!seenKeys.has(key)) {
      seenKeys.add(key);
      uniqueOptions.push(opt);
    }
  }

  // Default selection: walk if under 1 km (< 1000 m), otherwise the fastest option.
  let selectedIdx = 0;
  if (distKm < 1.0) {
    const walkIdx = uniqueOptions.findIndex((o) => o.mode === "walk");
    if (walkIdx !== -1) {
      selectedIdx = walkIdx;
    } else {
      selectedIdx = 0;
    }
  } else {
    // Pick the fastest option by durationSeconds
    let minSec = Infinity;
    let fastestIdx = 0;
    for (let i = 0; i < uniqueOptions.length; i++) {
      const sec = uniqueOptions[i].durationSeconds || 999999;
      if (sec < minSec) {
        minSec = sec;
        fastestIdx = i;
      }
    }
    selectedIdx = fastestIdx;
  }

  const selectedOption = uniqueOptions[selectedIdx] || uniqueOptions[0];

  const finalResult = {
    from: origin.name || "Start",
    to: destination.name || "Destination",
    distance: selectedOption.distance,
    distanceMeters: selectedOption.distanceMeters,
    duration: selectedOption.duration,
    durationMinutes: selectedOption.durationMinutes,
    durationSeconds: selectedOption.durationSeconds,
    mode: selectedOption.mode,
    transitLine: selectedOption.transitLine,
    cost: selectedOption.cost,
    boardingStop: selectedOption.boardingStop,
    alightingStop: selectedOption.alightingStop,
    stopCount: selectedOption.stopCount,
    departureTime: selectedOption.departureTime,
    polyline: selectedOption.polyline,
    options: uniqueOptions,
    selectedOptionIndex: selectedIdx,
    steps: selectedOption.steps || [],
  };

  routesCache.set(cacheKey, finalResult);
  return finalResult;
}

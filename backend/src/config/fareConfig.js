/**
 * Mumbai RTO Fare Configuration and Calculation Service
 *
 * Current rates are based on the latest Maharashtra Transport Department (RTO)
 * tariff card for the Mumbai Metropolitan Region (MMR).
 *
 * Flags / Uncertainties:
 * 1. Waiting Charges: Physical RTO meters charge waiting after 10 mins complete stoppage.
 *    In route calculation, we estimate traffic waiting delay from duration vs free-flow distance.
 * 2. Night Surcharge: Standard 25% surcharge applies between 00:00 (midnight) and 05:00 AM.
 * 3. App Cab Variance: Ola/Uber surge pricing may differ; these rates strictly reflect official RTO tariffs.
 */

export const MumbaiFareRates = {
  // Auto-Rickshaw (3-Wheeler)
  autoBaseFare: 23.0,
  autoBaseDistanceKm: 1.5,
  autoPerKmRate: 15.33,
  autoWaitingPerMin: 1.5,
  autoNightSurchargeMultiplier: 1.25,

  // Taxi / Cab (4-Wheeler Kaali-Peeli)
  cabBaseFare: 28.0,
  cabBaseDistanceKm: 1.5,
  cabPerKmRate: 18.66,
  cabWaitingPerMin: 2.0,
  cabNightSurchargeMultiplier: 1.25,

  // Cool Cab / AC Upper Reference
  acCabBaseFare: 33.0,
  acCabPerKmRate: 22.0,
};

export function calculateAutoFare(distanceKm, durationMinutes = 0, isNight = false) {
  if (distanceKm <= 0) {
    return { min: 23, max: 23, label: "est. ₹23" };
  }

  let distCost;
  if (distanceKm <= MumbaiFareRates.autoBaseDistanceKm) {
    distCost = MumbaiFareRates.autoBaseFare;
  } else {
    distCost =
      MumbaiFareRates.autoBaseFare +
      (distanceKm - MumbaiFareRates.autoBaseDistanceKm) * MumbaiFareRates.autoPerKmRate;
  }

  const freeFlowMins = (distanceKm / 25.0) * 60;
  const excessMins = Math.max(0, durationMinutes - freeFlowMins);
  const waitingLow = excessMins * 0.4 * MumbaiFareRates.autoWaitingPerMin;
  const waitingHigh = excessMins * 0.85 * MumbaiFareRates.autoWaitingPerMin;

  let minFare = distCost + waitingLow;
  let maxFare = distCost + waitingHigh;

  if (isNight) {
    minFare *= MumbaiFareRates.autoNightSurchargeMultiplier;
    maxFare *= MumbaiFareRates.autoNightSurchargeMultiplier;
  }

  const roundedMin = Math.max(Math.round(MumbaiFareRates.autoBaseFare), Math.round(minFare));
  const roundedMax = Math.max(roundedMin + 5, Math.round(maxFare));

  return {
    min: roundedMin,
    max: roundedMax,
    label: `est. ₹${roundedMin} - ₹${roundedMax}`,
  };
}

export function calculateCabFare(distanceKm, durationMinutes = 0, isNight = false) {
  if (distanceKm <= 0) {
    return { min: 28, max: 28, label: "est. ₹28" };
  }

  let distCost;
  if (distanceKm <= MumbaiFareRates.cabBaseDistanceKm) {
    distCost = MumbaiFareRates.cabBaseFare;
  } else {
    distCost =
      MumbaiFareRates.cabBaseFare +
      (distanceKm - MumbaiFareRates.cabBaseDistanceKm) * MumbaiFareRates.cabPerKmRate;
  }

  let upperDistCost;
  if (distanceKm <= MumbaiFareRates.cabBaseDistanceKm) {
    upperDistCost = MumbaiFareRates.acCabBaseFare;
  } else {
    upperDistCost =
      MumbaiFareRates.acCabBaseFare +
      (distanceKm - MumbaiFareRates.cabBaseDistanceKm) * MumbaiFareRates.acCabPerKmRate;
  }

  const freeFlowMins = (distanceKm / 22.0) * 60;
  const excessMins = Math.max(0, durationMinutes - freeFlowMins);
  const waitingLow = excessMins * 0.3 * MumbaiFareRates.cabWaitingPerMin;
  const waitingHigh = excessMins * 0.8 * MumbaiFareRates.cabWaitingPerMin;

  let minFare = distCost + waitingLow;
  let maxFare = upperDistCost + waitingHigh;

  if (isNight) {
    minFare *= MumbaiFareRates.cabNightSurchargeMultiplier;
    maxFare *= MumbaiFareRates.cabNightSurchargeMultiplier;
  }

  const roundedMin = Math.max(Math.round(MumbaiFareRates.cabBaseFare), Math.round(minFare));
  const roundedMax = Math.max(roundedMin + 8, Math.round(maxFare));

  return {
    min: roundedMin,
    max: roundedMax,
    label: `est. ₹${roundedMin} - ₹${roundedMax}`,
  };
}

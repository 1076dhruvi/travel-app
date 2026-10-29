/**
 * Converts minutes from midnight into 24-hour "HH:MM" format.
 */
export function minutesToTimeString(totalMinutes) {
  const normalized = Math.max(0, Math.min(23 * 60 + 59, Math.round(totalMinutes)));
  const hours = Math.floor(normalized / 60);
  const minutes = normalized % 60;
  return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}`;
}

/**
 * Parses time string (e.g. "09:30", "9:00 AM", "17:00", "5:30 PM") into minutes from midnight.
 */
export function parseTimeToMinutes(timeStr) {
  if (!timeStr || typeof timeStr !== "string") return null;

  const trimmed = timeStr.trim().toUpperCase();

  // "HH:MM AM/PM" or "HH AM/PM"
  const ampmMatch = trimmed.match(/^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$/);
  if (ampmMatch) {
    let hours = parseInt(ampmMatch[1], 10);
    const minutes = parseInt(ampmMatch[2] || "0", 10);
    const period = ampmMatch[3];

    if (period === "PM" && hours < 12) hours += 12;
    if (period === "AM" && hours === 12) hours = 0;
    return hours * 60 + minutes;
  }

  // "HH:MM" 24-hour format
  const match24 = trimmed.match(/^(\d{1,2}):(\d{2})$/);
  if (match24) {
    const hours = parseInt(match24[1], 10);
    const minutes = parseInt(match24[2], 10);
    return hours * 60 + minutes;
  }

  return null;
}

/**
 * Parses opening hours string to extract open and close minutes from midnight.
 * Examples: "09:00 - 18:00", "9:30 AM – 6:00 PM", "Open 24 hours"
 */
export function parseOpeningHoursRange(hoursStr) {
  if (!hoursStr || typeof hoursStr !== "string") return null;

  const lower = hoursStr.toLowerCase();
  if (lower.includes("24 hour") || lower.includes("24/7")) {
    return { openMinutes: 0, closeMinutes: 24 * 60 };
  }

  // Match range: "open - close"
  const rangeMatch = hoursStr.match(
    /(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)\s*[-–—to]+\s*(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)/i
  );

  if (rangeMatch) {
    const openMin = parseTimeToMinutes(rangeMatch[1]);
    const closeMin = parseTimeToMinutes(rangeMatch[2]);
    if (openMin !== null && closeMin !== null) {
      return { openMinutes: openMin, closeMinutes: closeMin };
    }
  }

  return null;
}

/**
 * Calculates arrival and leave times for each stop such that:
 * 1. Times are derived from real transit legs.
 * 2. Times strictly fit the venue's opening hours.
 *
 * @param {Array<Object>} stops - Ordered attraction stops
 * @param {Array<Object>} legs - Leg routes [start->stop1, stop1->stop2, ...]
 * @param {string} dayStart - Departure time from start point (default "09:00")
 */
export function calculateSchedule(stops, legs, dayStart = "09:00") {
  let currentMinutes = parseTimeToMinutes(dayStart) ?? 9 * 60; // 09:00

  for (let i = 0; i < stops.length; i++) {
    const stop = stops[i];
    const leg = legs && legs[i];
    const transitMins = leg ? Math.max(3, leg.durationMinutes || 15) : 15;

    // Arrival after transit leg
    let arrivalMinutes = currentMinutes + transitMins;

    // Opening hours validation & adjustment
    const hoursRange = parseOpeningHoursRange(stop.openingHours);
    if (hoursRange) {
      // If arrival is before the venue opens, visit starts when it opens
      if (arrivalMinutes < hoursRange.openMinutes) {
        arrivalMinutes = hoursRange.openMinutes;
      }
    }

    // Default visit duration: 1 hour (60 min)
    const plannedDurationMinutes = 60;
    let leaveMinutes = arrivalMinutes + plannedDurationMinutes;

    // Ensure leave time does not exceed closing hours if known
    if (hoursRange && hoursRange.closeMinutes < 24 * 60) {
      if (leaveMinutes > hoursRange.closeMinutes) {
        // If arrived before closing, adjust leave time to closing time
        if (arrivalMinutes < hoursRange.closeMinutes) {
          leaveMinutes = hoursRange.closeMinutes;
        }
      }
    }

    stop.arrivalTime = minutesToTimeString(arrivalMinutes);
    stop.leaveTime = minutesToTimeString(leaveMinutes);
    stop.duration = `${Math.round(leaveMinutes - arrivalMinutes)} min`;

    // Next leg departs from this stop at leaveTime
    currentMinutes = leaveMinutes;
  }
}

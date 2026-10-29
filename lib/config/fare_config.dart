import 'dart:math' as math;

/// Mumbai RTO Fare Configuration and Calculation Service.
///
/// Current rates are based on the latest Maharashtra Transport Department (RTO)
/// tariff card for the Mumbai Metropolitan Region (MMR).
///
/// Flags / Uncertainties:
/// 1. [waitingRatePerMin]: Physical RTO meters apply waiting charges after 10 minutes of complete stoppage.
///    In our route-based estimation, we approximate waiting time as 15%-25% of total trip duration
///    to reflect typical Mumbai road traffic conditions.
/// 2. [nightSurchargePercent]: Standard 25% surcharge applies between 00:00 (midnight) and 05:00 AM.
/// 3. [appCabVariance]: Ride-hailing services (Uber/Ola) use algorithmic surge pricing rather than
///    meter cards. Our cab estimate represents official metered black-and-yellow (Kaali-Peeli)
///    rates, with the upper bound reflecting peak-traffic or AC Cool Cab tariffs.
class MumbaiFareRates {
  // ── Auto-Rickshaw (3-Wheeler) RTO Tariff ─────────────────────────
  static const double autoBaseFare = 23.0; // Minimum fare for first 1.5 km
  static const double autoBaseDistanceKm = 1.5;
  static const double autoPerKmRate = 15.33; // Per km beyond 1.5 km
  static const double autoWaitingPerMin = 1.50; // Approx ₹1.50/min stoppage (FLAG: approximate traffic delay)
  static const double autoNightSurchargeMultiplier = 1.25; // 25% between 12 AM and 5 AM

  // ── Taxi / Cab (4-Wheeler Kaali-Peeli) RTO Tariff ─────────────────
  static const double cabBaseFare = 28.0; // Minimum fare for first 1.5 km
  static const double cabBaseDistanceKm = 1.5;
  static const double cabPerKmRate = 18.66; // Per km beyond 1.5 km
  static const double cabWaitingPerMin = 2.00; // Approx ₹2.00/min stoppage (FLAG: approximate traffic delay)
  static const double cabNightSurchargeMultiplier = 1.25; // 25% between 12 AM and 5 AM

  // ── AC Cool Cab / App Upper Reference ─────────────────────────────
  static const double acCabBaseFare = 33.0;
  static const double acCabPerKmRate = 22.0;

  /// Calculates estimated fare range for Auto-Rickshaw in Mumbai.
  /// Returns a [FareRange] with low and high estimates labeled "est. ₹X - ₹Y".
  static FareRange calculateAutoFare(
    double distanceKm,
    int durationMinutes, {
    bool isNight = false,
  }) {
    if (distanceKm <= 0) {
      return const FareRange(min: 23, max: 23, label: 'est. ₹23');
    }

    // Base distance computation
    double distCost;
    if (distanceKm <= autoBaseDistanceKm) {
      distCost = autoBaseFare;
    } else {
      distCost = autoBaseFare + (distanceKm - autoBaseDistanceKm) * autoPerKmRate;
    }

    // Traffic waiting estimation (approx 15% - 25% of duration in Mumbai traffic)
    final double freeFlowMins = (distanceKm / 25.0) * 60; // 25 km/h standard speed
    final double excessMins = math.max(0.0, durationMinutes - freeFlowMins);
    final double waitingCostLow = (excessMins * 0.4) * autoWaitingPerMin;
    final double waitingCostHigh = (excessMins * 0.85) * autoWaitingPerMin;

    double minFare = distCost + waitingCostLow;
    double maxFare = distCost + waitingCostHigh;

    if (isNight) {
      minFare *= autoNightSurchargeMultiplier;
      maxFare *= autoNightSurchargeMultiplier;
    }

    final int roundedMin = math.max(autoBaseFare.round(), minFare.round());
    final int roundedMax = math.max(roundedMin + 5, maxFare.round());

    return FareRange(
      min: roundedMin,
      max: roundedMax,
      label: 'est. ₹$roundedMin - ₹$roundedMax',
    );
  }

  /// Calculates estimated fare range for Cab / Taxi in Mumbai.
  /// Returns a [FareRange] with low and high estimates labeled "est. ₹X - ₹Y".
  static FareRange calculateCabFare(
    double distanceKm,
    int durationMinutes, {
    bool isNight = false,
  }) {
    if (distanceKm <= 0) {
      return const FareRange(min: 28, max: 28, label: 'est. ₹28');
    }

    // Kaali-Peeli baseline
    double distCost;
    if (distanceKm <= cabBaseDistanceKm) {
      distCost = cabBaseFare;
    } else {
      distCost = cabBaseFare + (distanceKm - cabBaseDistanceKm) * cabPerKmRate;
    }

    // Upper baseline (Cool cab / peak road traffic)
    double upperDistCost;
    if (distanceKm <= cabBaseDistanceKm) {
      upperDistCost = acCabBaseFare;
    } else {
      upperDistCost = acCabBaseFare + (distanceKm - cabBaseDistanceKm) * acCabPerKmRate;
    }

    final double freeFlowMins = (distanceKm / 22.0) * 60; // 22 km/h
    final double excessMins = math.max(0.0, durationMinutes - freeFlowMins);
    final double waitingCostLow = (excessMins * 0.3) * cabWaitingPerMin;
    final double waitingCostHigh = (excessMins * 0.8) * cabWaitingPerMin;

    double minFare = distCost + waitingCostLow;
    double maxFare = upperDistCost + waitingCostHigh;

    if (isNight) {
      minFare *= cabNightSurchargeMultiplier;
      maxFare *= cabNightSurchargeMultiplier;
    }

    final int roundedMin = math.max(cabBaseFare.round(), minFare.round());
    final int roundedMax = math.max(roundedMin + 8, maxFare.round());

    return FareRange(
      min: roundedMin,
      max: roundedMax,
      label: 'est. ₹$roundedMin - ₹$roundedMax',
    );
  }

  /// Combined Auto / Cab fare range
  static FareRange calculateCombinedAutoCabFare(
    double distanceKm,
    int durationMinutes, {
    bool isNight = false,
  }) {
    final auto = calculateAutoFare(distanceKm, durationMinutes, isNight: isNight);
    final cab = calculateCabFare(distanceKm, durationMinutes, isNight: isNight);

    return FareRange(
      min: auto.min,
      max: cab.max,
      label: 'est. ₹${auto.min} - ₹${cab.max}',
    );
  }

  /// Extracts numeric estimated min and max from any cost string like:
  /// "est. ₹38 - ₹45" -> (38, 45)
  /// "₹20" -> (20, 20)
  /// "Free" -> (0, 0)
  /// "check locally" -> (0, 0)
  static (int, int) parseCostToRange(String? cost) {
    if (cost == null || cost.isEmpty) return (0, 0);
    final trimmed = cost.trim().toLowerCase();
    if (trimmed == 'free') return (0, 0);
    if (trimmed.contains('check locally')) return (0, 0);

    final RegExp rangeRegex = RegExp(r'₹?\s*(\d+)\s*[-–—]\s*₹?\s*(\d+)');
    final match = rangeRegex.firstMatch(cost);
    if (match != null) {
      final low = int.tryParse(match.group(1) ?? '0') ?? 0;
      final high = int.tryParse(match.group(2) ?? '0') ?? low;
      return (low, high);
    }

    final RegExp singleRegex = RegExp(r'₹?\s*(\d+)');
    final singleMatch = singleRegex.firstMatch(cost);
    if (singleMatch != null) {
      final val = int.tryParse(singleMatch.group(1) ?? '0') ?? 0;
      return (val, val);
    }

    return (0, 0);
  }
}

/// Helper model for fare ranges
class FareRange {
  final int min;
  final int max;
  final String label;

  const FareRange({
    required this.min,
    required this.max,
    required this.label,
  });

  int get average => ((min + max) / 2).round();
}

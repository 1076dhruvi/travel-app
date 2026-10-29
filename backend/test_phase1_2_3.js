import "dotenv/config";
import app from "./src/app.js";
import { geocodePlace, geocodeDestination } from "./src/services/geocodeService.js";
import { getRoute } from "./src/services/routingService.js";

async function runTests() {
  console.log("=================================================");
  console.log("TRAVEL COMPANION - PHASE 1, 2, 3 INTEGRATION TEST");
  console.log("=================================================\n");

  let server;
  try {
    server = app.listen(3099);
    console.log("✓ Test server started on port 3099\n");

    // Test 1: Health check endpoint (GET /health)
    console.log("TEST 1: Health Check (GET /health & GET /api/health)");
    const healthRes = await fetch("http://localhost:3099/health");
    const healthJson = await healthRes.json();
    if (healthRes.status === 200 && healthJson.status === "OK") {
      console.log("✓ GET /health PASSED:", healthJson);
    } else {
      throw new Error(`GET /health failed: ${healthRes.status}`);
    }

    const apiHealthRes = await fetch("http://localhost:3099/api/health");
    const apiHealthJson = await apiHealthRes.json();
    if (apiHealthRes.status === 200 && apiHealthJson.status === "OK") {
      console.log("✓ GET /api/health PASSED:", apiHealthJson);
    } else {
      throw new Error(`GET /api/health failed: ${apiHealthRes.status}`);
    }

    // Test 2: Destination-agnostic Geocoding
    console.log("\nTEST 2: Worldwide Geocoding (Mumbai, Pune, Paris, Tokyo, New York, London)");
    const testCases = [
      { place: "Gateway of India", city: "Mumbai" },
      { place: "Shaniwar Wada", city: "Pune" },
      { place: "Eiffel Tower", city: "Paris" },
      { place: "Tokyo Tower", city: "Tokyo" },
      { place: "Empire State Building", city: "New York" },
      { place: "Big Ben", city: "London" }
    ];

    for (const tc of testCases) {
      const geo = await geocodePlace(tc.place, tc.city);
      console.log(`✓ Geocoded "${tc.place}" in "${tc.city}": [lat: ${geo.lat}, lng: ${geo.lng}]`);
      if (geo.lat == null || geo.lng == null) {
        throw new Error(`Invalid coords for ${tc.place}`);
      }
    }

    // Test 3: Free Road Routing (OSRM) with geometry
    console.log("\nTEST 3: Road Routing Pipeline (Louvre -> Arc de Triomphe in Paris)");
    const start = { name: "Louvre Museum", lat: 48.8606, lng: 2.3376 };
    const end = { name: "Arc de Triomphe", lat: 48.8738, lng: 2.2950 };
    const route = await getRoute(start, end);

    console.log(`✓ Route: ${route.from} → ${route.to}`);
    console.log(`✓ Distance: ${route.distance}, Time: ${route.time}`);
    console.log(`✓ Geometry vertices: ${route.geometry.length}`);
    console.log(`✓ First coordinate [lat, lon]:`, route.geometry[0]);
    console.log(`✓ Last coordinate [lat, lon]:`, route.geometry[route.geometry.length - 1]);

    if (!route.geometry || route.geometry.length < 2) {
      throw new Error("Route geometry missing or straight line fallback!");
    }

    // Test 4: Multi-stop route optimization endpoint
    console.log("\nTEST 4: POST /api/routing/optimize (Multi-stop Tokyo tour)");
    const optimizeRes = await fetch("http://localhost:3099/api/routing/optimize", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        city: "Tokyo",
        places: ["Tokyo Tower", "Sensō-ji", "Shinjuku Gyoen"]
      })
    });

    const optJson = await optimizeRes.json();
    if (optJson.success && optJson.routes?.length === 2 && optJson.fullRouteGeometry?.length > 10) {
      console.log(`✓ Optimize endpoint returned ${optJson.routes.length} legs and ${optJson.fullRouteGeometry.length} road coordinates!`);
      console.log(`  Leg 1: ${optJson.routes[0].from} → ${optJson.routes[0].to} (${optJson.routes[0].distance})`);
      console.log(`  Leg 2: ${optJson.routes[1].from} → ${optJson.routes[1].to} (${optJson.routes[1].distance})`);
    } else {
      console.error("Optimize response:", optJson);
      throw new Error("Optimize endpoint failed or returned incomplete route data");
    }

    console.log("\n=================================================");
    console.log("ALL TESTS PASSED SUCCESSFULLY! (100% ZERO COST)");
    console.log("=================================================");
  } catch (err) {
    console.error("❌ TEST FAILED:", err);
    process.exitCode = 1;
  } finally {
    if (server) server.close();
  }
}

runTests();

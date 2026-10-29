import "dotenv/config";
import { generateItineraryPlan } from "./src/services/geminiService.js";

async function main() {
  try {
    console.log("Testing generateItineraryPlan...");
    const res = await generateItineraryPlan("Mumbai", 1, ["sightseeing"]);
    console.log("Success! Attractions:", res[0]?.attractions?.length);
  } catch (err) {
    console.error("Gemini Error:", err);
  }
}
main();

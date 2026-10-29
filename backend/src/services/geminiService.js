import { GoogleGenerativeAI } from "@google/generative-ai";

/**
 * Invokes Gemini ONLY for geographic clustering and attraction selection.
 * Returns strict JSON with day groups and one-line reasons.
 * Real times, distances, routes, and opening hours come from external APIs, NOT Gemini.
 */
export async function generateItineraryPlan(destination, days = 2, interests = []) {
  const apiKey = process.env["GEMINI_API_KEY"];
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured in backend environment.");
  }

  const genAI = new GoogleGenerativeAI(apiKey);

  // Use fast, modern Gemini flash model
  let model;
  try {
    model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.2,
        maxOutputTokens: 3000,
      },
    });
  } catch (mErr) {
    model = genAI.getGenerativeModel({
      model: "gemini-1.5-flash",
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.2,
      },
    });
  }

  const prompt = `You are an expert geographical travel planner.
Create a ${days}-day travel itinerary for ${destination}.

Traveller interests: ${interests.length > 0 ? interests.join(", ") : "general sightseeing"}.

CLUSTERING RULES (MANDATORY):
1. Cluster places strictly by proximity so each day covers ONE distinct geographic area or neighbourhood of ${destination}.
2. NO area or neighbourhood may repeat on another day.
3. Include 3 to 4 real, verifiable tourist attractions per day.
4. Use ONLY real attractions searchable on Google Maps by their official name.
5. Do NOT include generic activities like "Food Tour", "Shopping Walk", "Sunset Cruise".
6. Do NOT fabricate arrival/leave times, travel distances, durations, or opening hours. External APIs will fetch them.

FOR EACH ATTRACTION, provide ONLY:
- "name": Official Google Maps name with city (e.g. "Mattancherry Palace, Kochi")
- "description": A single concise one-line reason to visit (e.g. "Historic 16th-century palace featuring elaborate Hindu temple murals and royal portraits.")
- "bestTime": Best time of day ("Morning", "Afternoon", "Evening", or "Sunset")

Return STRICT JSON matching this schema:
{
  "itinerary": [
    {
      "day": 1,
      "theme": "Theme of the day",
      "area": "Specific neighbourhood or district name",
      "attractions": [
        {
          "name": "Attraction Name, City",
          "description": "One-line factual reason to visit.",
          "bestTime": "Morning"
        }
      ]
    }
  ]
}`;

  const result = await model.generateContent(prompt);
  const responseText = result.response.text();
  const parsed = JSON.parse(responseText);

  if (!parsed || !Array.isArray(parsed.itinerary)) {
    throw new Error("Invalid itinerary JSON returned from Gemini.");
  }

  return parsed.itinerary;
}
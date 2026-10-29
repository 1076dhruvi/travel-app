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
      model: "gemini-3.5-flash-lite",
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

  const isMumbai = destination.toLowerCase().includes("mumbai");
  const mumbaiCuratedContext = isMumbai
    ? `
CURATED CANDIDATE ATTRACTIONS FOR MUMBAI (Select unique, diverse candidates across different days):
- South Mumbai (Fort, Colaba, Marine Drive): Gateway of India, Marine Drive, The Asiatic Society Mumbai, Horniman Circle, Flora Fountain, Colaba Causeway, Nariman Point
- Central / Seaside: Shree Siddhivinayak Temple, Haji Ali Dargah, Nehru Science Centre, Mahalakshmi Temple, Worli Sea Face
- Bandra & Suburbs: Bandra Fort (Castella de Aguada), Mount Mary Basilica, Bandra Bandstand, Carter Road Promenade
- North Suburbs & Nature: Juhu Beach, Kanheri Caves, Sanjay Gandhi National Park, Global Vipassana Pagoda
`
    : "";

  const prompt = `You are an expert geographical travel planner.
Create a ${days}-day travel itinerary for ${destination}.

Traveller interests: ${interests.length > 0 ? interests.join(", ") : "general sightseeing"}.
${mumbaiCuratedContext}
TRIP-WIDE PLACE UNIQUENESS & INTEGRITY (MANDATORY):
1. EACH ATTRACTION OR PLACE MAY APPEAR AT MOST ONCE ACROSS THE ENTIRE ${days}-DAY TRIP.
2. Absolutely NO attraction may repeat across multiple days. Every single place must be unique.
3. Return real, verifiable, distinct place names found on Google Maps.
4. Cluster places strictly by proximity so each day covers ONE distinct geographic neighbourhood or area (within ~5 km radius).
5. NO area or neighbourhood may repeat on another day.
6. Include 3 to 4 real tourist attractions per day.
7. Do NOT include generic activities like "Food Tour", "Shopping Walk", "Sunset Cruise".
8. Do NOT fabricate arrival/leave times, travel distances, durations, or opening hours. External APIs will fetch them.

FOR EACH ATTRACTION, provide ONLY:
- "name": Official Google Maps name with city (e.g. "Mattancherry Palace, Kochi")
- "description": A single concise one-line reason to visit.
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
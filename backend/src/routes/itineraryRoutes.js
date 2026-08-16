import express from "express";
import { GoogleGenerativeAI } from "@google/generative-ai";

const router = express.Router();

router.post("/generate", async (req, res) => {
  console.log("\n[LOG] Starting Itinerary Generation...");

  try {
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      return res.status(500).json({
        success: false,
        error: "GEMINI_API_KEY is not configured in backend/.env file",
      });
    }

    const { destination = "Kerala", days = 2, interests = [] } = req.body;

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-3.1-flash-lite",
      generationConfig: { responseMimeType: "application/json" },
    });

    const prompt = `Generate a ${days}-day travel itinerary for ${destination} focusing on: ${
      interests.length > 0 ? interests.join(", ") : "general sightseeing"
    }.

IMPORTANT GUIDELINES FOR ATTRACTION NAMES:
- The "name" property MUST BE ONLY a real, specific landmark, street, or venue name that can be searched on Google Maps (e.g., "Fort Kochi", "Mattancherry Market", "Alleppey Backwaters").
- Do NOT include activity descriptions, food terms, or extra text inside "name" (e.g., avoid "Breakfast at...", "Travel to...", "Street Food & Local Market Exploration").

Return strictly JSON matching this structure:
{
  "itinerary": [
    {
      "day": 1,
      "attractions": [
        {
          "name": "Fort Kochi",
          "description": "Street Food & Local Market Exploration",
          "bestTime": "Morning"
        }
      ]
    }
  ]
}`;

    console.log(`[LOG] Requesting Gemini API for ${destination} (${days} days)...`);

    const result = await model.generateContent(prompt);
    const responseText = result.response.text();
    const parsedJson = JSON.parse(responseText);

    console.log("[SUCCESS] Itinerary Generated Successfully!");
    return res.json(parsedJson);

  } catch (error) {
    console.error("[GEMINI API ERROR]:", error.message);
    return res.status(500).json({
      success: false,
      error: error.message || "Failed to generate itinerary",
    });
  }
});

export default router;
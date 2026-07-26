import { GoogleGenAI } from "@google/genai";
import { z } from "zod";
import { zodToJsonSchema } from "zod-to-json-schema";

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

const itinerarySchema = z.array(
    z.object({
        day: z.number(),
        attractions: z.array(
            z.object({
                name: z.string(),
                bestTime: z.string()
            })
        )
    })
);

export const generateItinerary = async (
    destination,
    days,
    interests
) => {

    const response = await ai.models.generateContent({

        model: "gemini-2.5-flash",

        contents: `

You are an expert travel planner.

Create a ${days}-day travel itinerary for ${destination}, India.

Traveller interests:
${interests.join(", ")}

Rules:

- Return ONLY valid JSON.
- Include ONLY real tourist attractions or landmarks.
- Every attraction MUST be searchable on Google Maps.
- Use official names of places.
- Do NOT include activities such as:
  - Street Food Tour
  - Shopping Experience
  - Sunset Cruise
  - Local Market Walk
  - Café Hopping
- Do NOT invent place names.
- Group nearby attractions together.
- Maximum 4 attractions per day.
- Include the best time to visit each attraction.

Format:

[
  {
    "day": 1,
    "attractions": [
      {
        "name": "Gateway of India",
        "bestTime": "Morning"
      }
    ]
  }
]

`,

        config: {
            temperature: 0.2,
            maxOutputTokens: 1500,
            responseMimeType: "application/json",
            responseSchema:
                zodToJsonSchema(itinerarySchema).schema
        }

    });

    const parsed = JSON.parse(response.text);

    console.log("Gemini Response:");
    console.log(JSON.stringify(parsed, null, 2));

    const validated = itinerarySchema.parse(parsed);

    return validated;
};
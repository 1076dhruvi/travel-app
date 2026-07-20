import { GoogleGenAI } from "@google/genai";
import { z } from "zod";
import { zodToJsonSchema } from "zod-to-json-schema";


const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});


// Gemini response format
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

        model: "gemini-3.1-flash-lite",

        contents: `

You are an expert travel planner.

Create a ${days}-day itinerary for ${destination}.

Traveller interests:
${interests.join(", ")}


Rules:

- Assume traveller is visiting for the first time.
- Include famous attractions.
- Include local experiences.
- Group nearby places together.
- Keep each day focused on a locality.
- Maximum 4 attractions per day.
- Return ONLY JSON.


Format:

[
 {
  "day":1,
  "attractions":[
   {
    "name":"place name",
    "bestTime":"morning"
   }
  ]
 }
]

        `,


        config: {

            temperature:0.2,

            maxOutputTokens:1500,

            responseMimeType:"application/json",

            responseSchema:
            zodToJsonSchema(itinerarySchema).schema

        }

    });



    const parsed =
    JSON.parse(response.text);



    const validated =
    itinerarySchema.parse(parsed);



    return validated;

};
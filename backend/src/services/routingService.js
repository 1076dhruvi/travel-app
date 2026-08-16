import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

/**
 * Calculates a driving route between two points using the Geoapify Routing API.
 *
 * @param {Object} start - Starting point object: { name: string, lat: number, lng: number }
 * @param {Object} end - Destination point object: { name: string, lat: number, lng: number }
 * @returns {Promise<{from: string, to: string, distance: string, time: string}>}
 */
export const getRoute = async (start, end) => {
    if (!API_KEY) {
        throw new Error("GEOAPIFY_API_KEY is not defined in environment variables.");
    }

    if (!start?.lat || !start?.lng || !end?.lat || !end?.lng) {
        throw new Error("Invalid start or end coordinates provided.");
    }

    try {
        console.log(`\nCalculating Route: ${start.name || "Start"} → ${end.name || "End"}`);

        const response = await axios.get("https://api.geoapify.com/v1/routing", {
            params: {
                waypoints: `${start.lat},${start.lng}|${end.lat},${end.lng}`,
                mode: "drive",
                avoid: "ferries",
                apiKey: API_KEY,
            },
            timeout: 10000, // 10-second request timeout
        });

        const feature = response.data?.features?.[0];

        if (!feature) {
            throw new Error(`No route found from ${start.name} to ${end.name}`);
        }

        const { distance, time } = feature.properties;

        return {
            from: start.name,
            to: end.name,
            distance: `${(distance / 1000).toFixed(2)} km`,
            time: `${Math.round(time / 60)} min`,
        };
    } catch (error) {
        if (axios.isAxiosError(error)) {
            console.error("Geoapify API Error Details:", error.response?.data || error.message);
            const apiMessage = error.response?.data?.message;
            throw new Error(apiMessage || `Geoapify API failed with status ${error.response?.status || 'UNKNOWN'}`);
        }

        console.error("Route calculation error:", error.message);
        throw error;
    }
};
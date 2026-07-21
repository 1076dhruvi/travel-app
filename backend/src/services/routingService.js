import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

export const getRoute = async (start, end) => {
    try {
        const response = await axios.get(
            "https://api.geoapify.com/v1/routing",
            {
                params: {
                    waypoints: `${start.lat},${start.lng}|${end.lat},${end.lng}`,
                    mode: "drive",
                    apiKey: API_KEY
                }
            }
        );

        const properties = response.data.features[0].properties;

        return {
            from: start.name,
            to: end.name,
            distance: (properties.distance / 1000).toFixed(2) + " km",
            time: Math.round(properties.time / 60) + " min"
        };

    } catch (error) {
        throw new Error(error.response?.data?.message || error.message);
    }
};
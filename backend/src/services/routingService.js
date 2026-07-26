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
                    avoid: "ferries",
                    apiKey: API_KEY
                }
            }
        );

        console.log(JSON.stringify(response.data.features[0].properties, null, 2));

        const properties = response.data.features[0].properties;

        return {
            from: start.name,
            to: end.name,
            distance: (properties.distance / 1000).toFixed(2) + " km",
            time: Math.round(properties.time / 60) + " min"
        };

    } catch (error) {

        console.log("Geoapify Error:");
        console.log(JSON.stringify(error.response?.data, null, 2));

        throw new Error(
            error.response?.data?.message || error.message
        );
    }
};
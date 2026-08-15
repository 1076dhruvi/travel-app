import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

export const getRoute = async (start, end) => {
    try {
        console.log("\nROUTE:");
        console.log(`${start.name} → ${end.name}`);
        console.log("START:", start.lat, start.lng);
        console.log("END:", end.lat, end.lng);

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

        if (
            !response.data.features ||
            response.data.features.length === 0
        ) {
            throw new Error(
                `No route found from ${start.name} to ${end.name}`
            );
        }

        const properties = response.data.features[0].properties;

        console.log("ROUTE DISTANCE:", properties.distance, "meters");
        console.log("ROUTE TIME:", properties.time, "seconds");

        return {
            from: start.name,
            to: end.name,
            distance: (properties.distance / 1000).toFixed(2) + " km",
            time: Math.round(properties.time / 60) + " min"
        };

    } catch (error) {
        console.log("Geoapify Error:");
        console.log(
            JSON.stringify(error.response?.data, null, 2)
        );

        throw new Error(
            error.response?.data?.message || error.message
        );
    }
};
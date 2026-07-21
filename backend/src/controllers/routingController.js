import { geocodePlace } from "../services/geocodeService.js";
import { getRoute } from "../services/routingService.js";

export const optimizeItinerary = async (req, res) => {
    try {

        const { places } = req.body;

        // Convert place names to coordinates
        const coordinates = [];

        for (const place of places) {
            const location = await geocodePlace(place);
            coordinates.push(location);
        }

        // Calculate routes between consecutive places
        const routes = [];

        for (let i = 0; i < coordinates.length - 1; i++) {
            const route = await getRoute(
                coordinates[i],
                coordinates[i + 1]
            );

            routes.push(route);
        }

        res.status(200).json({
            success: true,
            coordinates,
            routes
        });

    } catch (error) {

        res.status(500).json({
            success: false,
            error: error.message
        });

    }
};
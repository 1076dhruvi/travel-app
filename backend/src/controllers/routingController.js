import { geocodePlace } from "../services/geocodeService.js";
import { getRoute } from "../services/routingService.js";

export const optimizeItinerary = async (req, res) => {

    try {

        const { city, places } = req.body;

        const coordinates = [];

        for (const place of places) {

            const location = await geocodePlace(
                place,
                req.body.city
            );

            coordinates.push(location);
        }

        const routes = [];

        for (let i = 0; i < coordinates.length - 1; i++) {

            console.log(
                "Routing from:",
                coordinates[i],
                "to:",
                coordinates[i + 1]
            );

            const route = await getRoute(
                coordinates[i],
                coordinates[i + 1]
            );

            routes.push(route);
        }

        res.json({
            success: true,
            coordinates,
            routes
        });

    } catch (error) {

        console.log("OPTIMIZE ERROR:", error.message);

        res.status(500).json({
            success: false,
            error: error.message
        });

    }

};
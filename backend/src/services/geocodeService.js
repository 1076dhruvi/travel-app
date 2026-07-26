import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

export const geocodePlace = async (placeName, city) => {
    try {

        const response = await axios.get(
            "https://api.geoapify.com/v1/geocode/search",
            {
                params: {
                    text: `${placeName}, ${city}, India`,
                    apiKey: API_KEY
                }
            }
        );

        if (response.data.features.length === 0) {
            throw new Error(`No location found for ${placeName}`);
        }

        const place = response.data.features[0];

        console.log("Geocoded:", placeName);
        console.log(place.properties.formatted);
        console.log(place.properties.lat, place.properties.lon);

        return {
            name: placeName,
            lat: place.properties.lat,
            lng: place.properties.lon
        };

    } catch (error) {

        console.log("GEOCODING ERROR:", error.response?.data);

        throw new Error(error.message);
    }
};
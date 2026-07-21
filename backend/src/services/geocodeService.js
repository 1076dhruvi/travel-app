import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

export const geocodePlace = async (placeName) => {
    try {
        const url = "https://api.geoapify.com/v1/geocode/search";

        const response = await axios.get(url, {
           params: {
               text: `${placeName}, Mumbai, India`,
               apiKey: API_KEY
           }
        });

        if (response.data.features.length === 0) {
            throw new Error(`No location found for ${placeName}`);
        }

        const place = response.data.features[0];

        return {
            name: placeName,
            lat: place.properties.lat,
            lng: place.properties.lon
        };

    } catch (error) {
        throw new Error(error.message);
    }
};
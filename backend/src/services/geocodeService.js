import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

const knownPlaces = {
    "Gateway of India": {
        lat: 18.9220,
        lng: 72.8347
    },
    "Colaba Causeway": {
        lat: 18.9229,
        lng: 72.8245
    },
    "Chhatrapati Shivaji Maharaj Vastu Sangrahalaya": {
        lat: 18.9269,
        lng: 72.8310
    },
    "Crawford Market": {
        lat: 18.9477,
        lng: 72.8357
    },
    "Sanjay Gandhi National Park": {
        lat: 19.2147,
        lng: 72.9106
    },
    "Kanheri Caves": {
        lat: 19.2074,
        lng: 72.9066
    }
};

const geocodeCity = async (city) => {
    const response = await axios.get(
        "https://api.geoapify.com/v1/geocode/search",
        {
            params: {
                text: `${city}, India`,
                apiKey: API_KEY,
                filter: "countrycode:in",
                limit: 5
            }
        }
    );

    if (
        !response.data.features ||
        response.data.features.length === 0
    ) {
        throw new Error(`Could not find city: ${city}`);
    }

    const cityResult = response.data.features[0];

    return {
        lat: cityResult.properties.lat,
        lng: cityResult.properties.lon
    };
};

export const geocodePlace = async (placeName, city) => {
    try {
        if (!city) {
            throw new Error("City is required for geocoding.");
        }

        // Use verified coordinates for places we already know
        const knownPlace = knownPlaces[placeName];

        if (knownPlace) {
            console.log(`Using known coordinates: ${placeName}`);

            return {
                name: placeName,
                lat: knownPlace.lat,
                lng: knownPlace.lng
            };
        }

        // Get the center of the requested city
        const cityCenter = await geocodeCity(city);

        const response = await axios.get(
            "https://api.geoapify.com/v1/geocode/search",
            {
                params: {
                    text: `${placeName}, ${city}, India`,
                    apiKey: API_KEY,
                    filter: "countrycode:in",
                    bias: `proximity:${cityCenter.lng},${cityCenter.lat}`,
                    limit: 5
                }
            }
        );

        const features = response.data.features;

        if (!features || features.length === 0) {
            throw new Error(
                `No location found for ${placeName} in ${city}`
            );
        }

        const cityLower = city.toLowerCase();

        let place = features.find((feature) => {
            const properties = feature.properties;

            const resultCity =
                properties.city ||
                properties.county ||
                properties.state_district ||
                "";

            return resultCity
                .toLowerCase()
                .includes(cityLower);
        });

        if (!place) {
            place = features[0];
        }

        console.log(`Geocoded: ${placeName}`);
        console.log("Requested city:", city);
        console.log("Found:", place.properties.formatted);
        console.log(
            "Coordinates:",
            place.properties.lat,
            place.properties.lon
        );

        return {
            name: placeName,
            lat: place.properties.lat,
            lng: place.properties.lon
        };

    } catch (error) {
        console.log(
            "GEOCODING ERROR:",
            error.response?.data || error.message
        );

        throw error;
    }
};
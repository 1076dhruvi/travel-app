import axios from "axios";

const API_KEY = process.env.GEOAPIFY_API_KEY;

const GEOCODING_URL =
    "https://api.geoapify.com/v1/geocode/search";


// ============================================================
// HELPERS
// ============================================================

const normalize = (value) => {
    return (value || "")
        .toString()
        .toLowerCase()
        .trim()
        .replace(/[,'".()-]/g, " ")
        .replace(/\s+/g, " ");
};


const distanceKm = (lat1, lon1, lat2, lon2) => {

    const R = 6371;

    const dLat =
        (lat2 - lat1) * Math.PI / 180;

    const dLon =
        (lon2 - lon1) * Math.PI / 180;

    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(lat1 * Math.PI / 180) *
        Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) ** 2;

    return (
        R *
        2 *
        Math.atan2(
            Math.sqrt(a),
            Math.sqrt(1 - a)
        )
    );
};


// ============================================================
// EXTRACT DESTINATION CONTEXT
// ============================================================

const getDestinationParts = (city) => {

    const parts = city
        .split(",")
        .map(x => x.trim())
        .filter(Boolean);

    return {
        first: parts[0] || "",
        second: parts[1] || "",
        country:
            parts.find(
                x =>
                    normalize(x) === "india" ||
                    normalize(x) === "ind"
            ) || "India"
    };
};


// ============================================================
// EXTRACT LOCALITY FROM PLACE
// ============================================================

const getPlaceParts = (placeName) => {

    const parts = placeName
        .split(",")
        .map(x => x.trim())
        .filter(Boolean);

    return {
        name: parts[0] || "",
        locality: parts[1] || ""
    };
};


// ============================================================
// GEOCODE DESTINATION CENTER
// ============================================================

const geocodeDestination = async (city) => {

    const destination = getDestinationParts(city);

    const searches = [
        `${city}`,
        `${destination.first}, India`
    ];

    for (const text of searches) {

        try {

            const response = await axios.get(
                GEOCODING_URL,
                {
                    params: {
                        text,
                        apiKey: API_KEY,
                        filter: "countrycode:in",
                        limit: 5
                    }
                }
            );

            const features =
                response.data?.features || [];

            if (features.length > 0) {

                const p =
                    features[0].properties;

                if (
                    p?.lat != null &&
                    p?.lon != null
                ) {
                    return {
                        lat: Number(p.lat),
                        lng: Number(p.lon)
                    };
                }
            }

        } catch (error) {

            console.log(
                "Destination lookup failed:",
                text
            );

        }
    }

    return null;
};


// ============================================================
// SCORE A GEOCODING RESULT
//
// IMPORTANT:
// This is intentionally NOT strict.
//
// We mainly care that:
// 1. It is in India
// 2. It resembles the requested place
// 3. It is reasonably close to the destination
//
// We do NOT require exact city matching.
// ============================================================

const scoreResult = (
    feature,
    cleanedPlace,
    locality,
    destination,
    destinationCenter
) => {

    const p =
        feature.properties || {};

    const formatted =
        normalize(p.formatted);

    const name =
        normalize(p.name);

    const city =
        normalize(p.city);

    const county =
        normalize(p.county);

    const state =
        normalize(p.state);

    const stateDistrict =
        normalize(p.state_district);

    const country =
        normalize(p.country);

    const requestedPlace =
        normalize(cleanedPlace);

    const requestedLocality =
        normalize(locality);

    let score = 0;


    // --------------------------------------------------------
    // COUNTRY
    // --------------------------------------------------------

    if (
        country === "india" ||
        country === "ind"
    ) {
        score += 20;
    }


    // --------------------------------------------------------
    // EXACT PLACE NAME
    // --------------------------------------------------------

    if (
        name &&
        requestedPlace &&
        name === requestedPlace
    ) {
        score += 60;
    }

    if (
        formatted.includes(requestedPlace)
    ) {
        score += 35;
    }


    // --------------------------------------------------------
    // LOCALITY
    //
    // Example:
    //
    // Tiger's Leap, Lonavala
    // Robber's Cave, Dehradun
    // Sabarmati Ashram, Ahmedabad
    // --------------------------------------------------------

    if (
        requestedLocality &&
        (
            city === requestedLocality ||
            county === requestedLocality ||
            stateDistrict === requestedLocality ||
            formatted.includes(requestedLocality)
        )
    ) {
        score += 40;
    }


    // --------------------------------------------------------
    // DESTINATION CONTEXT
    //
    // Do NOT require exact match.
    //
    // Gujarat can contain:
    // Ahmedabad
    // Kevadia
    // Gandhinagar
    //
    // Uttarakhand can contain:
    // Dehradun
    // Mussoorie
    // Rishikesh
    // --------------------------------------------------------

    const destinationFirst =
        normalize(destination.first);

    const destinationSecond =
        normalize(destination.second);


    if (
        destinationFirst &&
        (
            city === destinationFirst ||
            county === destinationFirst ||
            state === destinationFirst ||
            stateDistrict === destinationFirst ||
            formatted.includes(destinationFirst)
        )
    ) {
        score += 15;
    }


    if (
        destinationSecond &&
        (
            city === destinationSecond ||
            county === destinationSecond ||
            state === destinationSecond ||
            stateDistrict === destinationSecond ||
            formatted.includes(destinationSecond)
        )
    ) {
        score += 15;
    }


    // --------------------------------------------------------
    // DISTANCE FROM DESTINATION CENTER
    //
    // This is a SOFT score, not a hard rejection.
    // --------------------------------------------------------

    if (
        destinationCenter &&
        p.lat != null &&
        p.lon != null
    ) {

        const distance =
            distanceKm(
                destinationCenter.lat,
                destinationCenter.lng,
                Number(p.lat),
                Number(p.lon)
            );

        console.log(
            `Candidate: ${p.formatted} | ${distance.toFixed(1)} km`
        );


        // Very close = strong bonus
        if (distance <= 10) {
            score += 30;
        }

        else if (distance <= 30) {
            score += 20;
        }

        else if (distance <= 60) {
            score += 10;
        }

        // We deliberately DON'T reject far candidates here.
        // Name/locality matching can still win.
    }


    return score;
};


// ============================================================
// GEOCODE PLACE
// ============================================================

export const geocodePlace = async (
    placeName,
    city
) => {

    console.log("\n=================================");
    console.log("GEOCODING");
    console.log("PLACE:", placeName);
    console.log("DESTINATION:", city);
    console.log("=================================");


    try {

        if (!placeName) {
            throw new Error(
                "Place name is required."
            );
        }

        if (!city) {
            throw new Error(
                "Destination is required."
            );
        }

        if (!API_KEY) {
            throw new Error(
                "GEOAPIFY_API_KEY is not configured."
            );
        }


        // ----------------------------------------------------
        // Parse place
        // ----------------------------------------------------

        const placeParts =
            getPlaceParts(placeName);

        const cleanedPlace =
            placeParts.name;

        const locality =
            placeParts.locality;


        const destination =
            getDestinationParts(city);


        console.log(
            "PLACE NAME:",
            cleanedPlace
        );

        console.log(
            "LOCALITY:",
            locality
        );

        console.log(
            "DESTINATION:",
            destination
        );


        // ----------------------------------------------------
        // Get destination center
        // ----------------------------------------------------

        const destinationCenter =
            await geocodeDestination(city);


        // ----------------------------------------------------
        // Build multiple search queries
        //
        // Start specific.
        // Then gradually broaden.
        // ----------------------------------------------------

        const queries = [];

        if (locality) {

            queries.push(
                `${cleanedPlace}, ${locality}, ${city}`
            );

            queries.push(
                `${cleanedPlace}, ${locality}, India`
            );

            queries.push(
                `${cleanedPlace}, ${locality}`
            );
        }


        queries.push(
            `${cleanedPlace}, ${city}`
        );

        queries.push(
            `${cleanedPlace}, India`
        );

        queries.push(
            cleanedPlace
        );


        // Remove duplicate queries

        const uniqueQueries =
            [...new Set(queries)];


        let allCandidates = [];


        // ----------------------------------------------------
        // SEARCH ALL QUERIES
        // ----------------------------------------------------

        for (const query of uniqueQueries) {

            console.log(
                "\nSEARCHING:",
                query
            );


            try {

                const response =
                    await axios.get(
                        GEOCODING_URL,
                        {
                            params: {

                                text: query,

                                apiKey: API_KEY,

                                filter:
                                    "countrycode:in",

                                limit: 10
                            }
                        }
                    );


                const features =
                    response.data?.features || [];


                console.log(
                    "RESULTS:",
                    features.length
                );


                for (const feature of features) {

                    const p =
                        feature.properties || {};


                    if (
                        p.lat == null ||
                        p.lon == null
                    ) {
                        continue;
                    }


                    const score =
                        scoreResult(
                            feature,
                            cleanedPlace,
                            locality,
                            destination,
                            destinationCenter
                        );


                    allCandidates.push({
                        feature,
                        score
                    });

                }

            } catch (error) {

                console.log(
                    "SEARCH FAILED:",
                    query
                );

            }
        }


        // ----------------------------------------------------
        // REMOVE DUPLICATE COORDINATES
        // ----------------------------------------------------

        const uniqueCandidates = [];

        const seen =
            new Set();


        for (const candidate of allCandidates) {

            const p =
                candidate.feature.properties;

            const key =
                `${p.lat},${p.lon}`;


            if (seen.has(key)) {
                continue;
            }

            seen.add(key);

            uniqueCandidates.push(
                candidate
            );
        }


        // ----------------------------------------------------
        // SORT BY SCORE
        // ----------------------------------------------------

        uniqueCandidates.sort(
            (a, b) =>
                b.score - a.score
        );


        // ----------------------------------------------------
        // DEBUG
        // ----------------------------------------------------

        console.log(
            "\nCANDIDATE RESULTS:"
        );


        uniqueCandidates
            .slice(0, 10)
            .forEach(
                (candidate, index) => {

                    console.log(
                        `${index + 1}.`,
                        candidate.feature
                            .properties
                            ?.formatted
                    );

                    console.log(
                        "   SCORE:",
                        candidate.score
                    );

                    console.log(
                        "   COORD:",
                        candidate.feature
                            .properties
                            ?.lat,
                        candidate.feature
                            .properties
                            ?.lon
                    );

                }
            );


        // ----------------------------------------------------
        // NO RESULTS
        // ----------------------------------------------------

        if (
            uniqueCandidates.length === 0
        ) {

            throw new Error(
                `No location found for "${placeName}".`
            );

        }


        // ----------------------------------------------------
        // TAKE BEST RESULT
        //
        // IMPORTANT:
        // We intentionally use a LOW threshold.
        //
        // This prevents the problem where legitimate
        // attractions get rejected just because their
        // administrative city doesn't match perfectly.
        // ----------------------------------------------------

        const best =
            uniqueCandidates[0];


        const properties =
            best.feature.properties;


        console.log(
            "\nSELECTED:"
        );

        console.log(
            properties.formatted
        );

        console.log(
            "SCORE:",
            best.score
        );

        console.log(
            "COORDINATES:",
            properties.lat,
            properties.lon
        );


        return {

            name: placeName,

            lat: Number(
                properties.lat
            ),

            lng: Number(
                properties.lon
            )

        };


    } catch (error) {

        console.log(
            "\nGEOCODING ERROR:"
        );

        console.log(
            error.response?.data ||
            error.message
        );

        throw error;
    }
};
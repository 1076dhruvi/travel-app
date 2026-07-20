import express from "express";
import itineraryRoutes from "./routes/itineraryRoutes.js";


const app = express();


app.use(express.json());


app.use(
    "/api/itinerary",
    itineraryRoutes
);


export default app;
import express from "express";
import itineraryRoutes from "./routes/itineraryRoutes.js";
import routingRoutes from "./routes/routingRoutes.js";


const app = express();


app.use(express.json());


app.use(
    "/api/itinerary",
    itineraryRoutes
);
app.use("/api/routing", routingRoutes);

export default app;
import { generateItinerary } from "../services/geminiService.js";


export const createItinerary = async(req,res)=>{

    try{


        const {
            destination,
            days,
            interests
        } = req.body;



        const itinerary =
        await generateItinerary(
            destination,
            days,
            interests
        );


        res.json({

            destination,

            days,

            itinerary

        });


    }
    catch(error){


        console.log(error);


        res.status(500).json({

            message:"Failed to generate itinerary"

        });


    }

};


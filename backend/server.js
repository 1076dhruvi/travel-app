import "dotenv/config";
import app from "./src/app.js";

const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT} and listening across network interface at http://0.0.0.0:${PORT}`);
});
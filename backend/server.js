import "dotenv/config";
import app from "./src/app.js";

const PORT = 3000;

// Explicitly bind to '0.0.0.0' so Android Emulator (10.0.2.2) can connect
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
});
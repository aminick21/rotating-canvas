import express from "express";
import cors from "cors";
import dotenv from "dotenv";
dotenv.config();
import http from "http";
import { setupSocketServer } from "./socketServer.js";

// Create Express app
const app = express();

// CORS configuration
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "http://localhost:3000",
    credentials: true,
  })
);

// Body parsing middleware
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Global error handler
app.use((err, req, res, next) => {
  console.error("Error:", err);
  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal Server Error";
  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
});

// Create HTTP server and attach Socket.IO
const server = http.createServer(app);
setupSocketServer(server);

// Export both app and server
export default server;
export { app };

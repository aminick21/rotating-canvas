import { Server } from "socket.io";

let users = [];
let currentTurnIndex = 0;
let timer = null;
let timeLeft = 30;

function startTurn(io) {
  if (users.length === 0) return;
  timeLeft = 30;
  const currentUser = users[currentTurnIndex];
  console.log(`Starting turn for user: ${currentUser.id}`);
  console.log("[SOCKET] Emitting turn:", { userId: currentUser.id, timeLeft });
  io.emit("turn", { userId: currentUser.id, timeLeft });
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    timeLeft -= 1;
    console.log("[SOCKET] Emitting timer:", { timeLeft });
    io.emit("timer", { timeLeft });
    if (timeLeft <= 0) {
      clearInterval(timer);
      console.log("Turn ended, moving to next user");
      nextTurn(io);
    }
  }, 1000);
}

function nextTurn(io) {
  if (users.length === 0) return;
  currentTurnIndex = (currentTurnIndex + 1) % users.length;
  startTurn(io);
}

function setupSocketServer(server) {
  const io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  io.on("connection", (socket) => {
    console.log(`User connected: ${socket.id}`);
    users.push({ id: socket.id });
    console.log(
      "[SOCKET] Emitting userList:",
      users.map((u) => u.id)
    );
    io.emit(
      "userList",
      users.map((u) => u.id)
    );
    if (users.length === 1) {
      currentTurnIndex = 0;
      startTurn(io);
    } else {
      const currentUser = users[currentTurnIndex];
      console.log("[SOCKET] Emitting turn (to new user):", {
        userId: currentUser.id,
        timeLeft,
      });
      socket.emit("turn", { userId: currentUser.id, timeLeft });
    }

    socket.on("drawing", (data) => {
      if (users.length === 0) return;
      const currentUser = users[currentTurnIndex];
      if (socket.id === currentUser.id) {
        console.log(`Drawing event from user: ${socket.id}`);
        console.log("[SOCKET] Drawing data received:", {
          type: data.type,
          userId: socket.id,
          timestamp: data.timestamp,
          hasStrokeData: !!data.strokeData,
        });

        // Broadcast to all other clients (not including the sender)
        socket.broadcast.emit("drawing", {
          userId: socket.id,
          type: data.type,
          strokeData: data.strokeData,
          timestamp: data.timestamp || Date.now(),
        });
      } else {
        console.log(
          `Drawing event from non-current user: ${socket.id}, current user: ${currentUser.id}`
        );
      }
    });

    socket.on("disconnect", () => {
      const idx = users.findIndex((u) => u.id === socket.id);
      if (idx !== -1) {
        users.splice(idx, 1);
        console.log(`User disconnected: ${socket.id}`);
        if (idx < currentTurnIndex || currentTurnIndex >= users.length) {
          currentTurnIndex = currentTurnIndex === 0 ? 0 : currentTurnIndex - 1;
        }
        console.log(
          "[SOCKET] Emitting userList:",
          users.map((u) => u.id)
        );
        io.emit(
          "userList",
          users.map((u) => u.id)
        );
        if (users.length === 0) {
          clearInterval(timer);
          timer = null;
        } else {
          startTurn(io);
        }
      }
    });
  });
}

export { setupSocketServer };

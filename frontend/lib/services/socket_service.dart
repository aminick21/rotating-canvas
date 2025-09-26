import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/drawing_data.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  Function(GameState)? _gameStateCallback;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String serverUrl) {
    if (_socket?.connected == true) return;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    // Register listeners BEFORE connect to avoid missing initial events
    _socket!.onConnect((_) {
      print('Connected to server');
    });

    _socket!.onDisconnect((_) {
      print('Disconnected from server');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    // Register game state listeners if callback is already set
    if (_gameStateCallback != null) {
      _registerGameStateListeners();
    }

    _socket!.connect();
    addDebugEventLogger();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // Listen for game state changes
  void listenToGameState(Function(GameState) onGameStateUpdate) {
    print('[SocketService] listenToGameState called');
    _gameStateCallback = onGameStateUpdate;

    // If socket is already connected, register listeners immediately
    if (_socket?.connected == true) {
      _registerGameStateListeners();
    }
  }

  void _registerGameStateListeners() {
    print('[SocketService] Registering game state listeners');
    GameState currentState = const GameState();

    _socket?.onConnect((_) {
      print('[SocketService] Socket connected');
      currentState = currentState.copyWith(isConnected: true);
      print('[SocketService] About to call onGameStateUpdate with: $currentState');
      _gameStateCallback?.call(currentState);
    });

    _socket?.on('userList', (data) {
      print('[SocketService] Received userList: $data');
      List<String> users = List<String>.from(data);
      currentState = currentState.copyWith(
        users: users,
        isConnected: true,
        currentTurnUserId: currentState.currentTurnUserId,
        timeLeft: currentState.timeLeft,
      );
      print('[SocketService] About to call onGameStateUpdate with: $currentState');
      _gameStateCallback?.call(currentState);
    });

    _socket?.on('turn', (data) {
      print('[SocketService] Received turn: $data');
      currentState = currentState.copyWith(
        currentTurnUserId: data['userId'],
        timeLeft: data['timeLeft'] ?? currentState.timeLeft,
        users: currentState.users,
        isConnected: true,
      );
      print('[SocketService] About to call onGameStateUpdate with: $currentState');
      _gameStateCallback?.call(currentState);
    });

    _socket?.on('timer', (data) {
      print('[SocketService] Received timer: $data');
      currentState = currentState.copyWith(
        timeLeft: data['timeLeft'] ?? currentState.timeLeft,
        users: currentState.users,
        currentTurnUserId: currentState.currentTurnUserId,
        isConnected: true,
      );
      print('[SocketService] About to call onGameStateUpdate with: $currentState');
      _gameStateCallback?.call(currentState);
    });

    _socket?.onDisconnect((_) {
      print('[SocketService] Socket disconnected');
      currentState = currentState.copyWith(isConnected: false);
      print('[SocketService] About to call onGameStateUpdate with: $currentState');
      _gameStateCallback?.call(currentState);
    });
  }

  // Listen for drawing data from other users
  void listenToDrawingData(Function(DrawingData) onDrawingData) {
    _socket?.on('drawing', (data) {
      try {
        final drawingData = DrawingData.fromJson(data);
        onDrawingData(drawingData);
      } catch (e) {
        print('Error parsing drawing data: $e');
      }
    });
  }

  // Send drawing data to server
  void sendDrawingData(DrawingData drawingData) {
    if (_socket?.connected == true) {
      _socket!.emit('drawing', drawingData.toJson());
    }
  }

  void addDebugEventLogger() {
    _socket?.onAny((event, data) {
      print('[SocketService] Received event: $event, data: $data');
    });
  }

  String? get socketId => _socket?.id;
}

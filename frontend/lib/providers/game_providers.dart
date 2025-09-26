import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drawing_data.dart';
import '../services/socket_service.dart';

// Socket service provider
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

// Game state provider
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return GameStateNotifier(socketService);
});

// Drawing strokes provider
final drawingStrokesProvider = StateNotifierProvider<DrawingStrokesNotifier, List<DrawingData>>((
  ref,
) {
  final socketService = ref.watch(socketServiceProvider);
  return DrawingStrokesNotifier(socketService);
});

// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return socketService.socketId;
});

// Is current user's turn provider
final isCurrentUserTurnProvider = Provider<bool>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return gameState.currentTurnUserId == currentUserId && gameState.isConnected;
});

class GameStateNotifier extends StateNotifier<GameState> {
  final SocketService _socketService;

  GameStateNotifier(this._socketService) : super(const GameState()) {
    _socketService.listenToGameState(_updateGameState);
  }

  void _updateGameState(GameState newState) {
    print(
      '[GameStateNotifier] Game state updated: '
      'currentTurnUserId=${newState.currentTurnUserId}, '
      'timeLeft=${newState.timeLeft}, '
      'users=${newState.users}, '
      'isConnected=${newState.isConnected}',
    );
    state = newState;
  }

  void connect(String serverUrl) {
    print('[GameStateNotifier] Connecting to server: $serverUrl');
    _socketService.connect(serverUrl);
  }

  void disconnect() {
    print('[GameStateNotifier] Disconnecting from server');
    _socketService.disconnect();
    state = const GameState();
  }
}

class DrawingStrokesNotifier extends StateNotifier<List<DrawingData>> {
  final SocketService _socketService;

  DrawingStrokesNotifier(this._socketService) : super([]) {
    _socketService.listenToDrawingData(_addDrawingData);
  }

  void _addDrawingData(DrawingData drawingData) {
    print('[DrawingStrokesNotifier] Received drawing data from user: ${drawingData.userId}');
    state = [...state, drawingData];
  }

  void sendDrawingData(DrawingData drawingData) {
    print('[DrawingStrokesNotifier] Sending drawing data for user: ${drawingData.userId}');
    // Add to local state immediately for responsiveness
    state = [...state, drawingData];
    // Send to server
    _socketService.sendDrawingData(drawingData);
  }

  void addLocalStroke(DrawingData drawingData) {
    print('[DrawingStrokesNotifier] Adding local stroke for user: ${drawingData.userId}');
    // Add to local state immediately for responsiveness
    state = [...state, drawingData];
    // Send to server
    _socketService.sendDrawingData(drawingData);
  }

  void clearCanvas() {
    print('[DrawingStrokesNotifier] Clearing canvas');
    state = [];
  }
}

class DrawingData {
  final String type; // 'stroke', 'clear', 'undo', 'redo'
  final Map<String, dynamic>? strokeData; // Raw stroke data from DrawingController
  final String userId;
  final DateTime timestamp;

  DrawingData({required this.type, this.strokeData, required this.userId, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  factory DrawingData.fromJson(Map<String, dynamic> json) {
    return DrawingData(
      type: json['type'] ?? '',
      strokeData: json['strokeData'],
      userId: json['userId'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'strokeData': strokeData,
      'userId': userId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory DrawingData.stroke({required Map<String, dynamic> strokeData, required String userId}) {
    return DrawingData(type: 'stroke', strokeData: strokeData, userId: userId);
  }

  factory DrawingData.clear({required String userId}) {
    return DrawingData(type: 'clear', userId: userId);
  }

  factory DrawingData.undo({required String userId}) {
    return DrawingData(type: 'undo', userId: userId);
  }

  factory DrawingData.redo({required String userId}) {
    return DrawingData(type: 'redo', userId: userId);
  }
}

class GameState {
  final String? currentTurnUserId;
  final int timeLeft;
  final List<String> users;
  final bool isConnected;

  const GameState({
    this.currentTurnUserId,
    this.timeLeft = 0,
    this.users = const [],
    this.isConnected = false,
  });

  GameState copyWith({
    String? currentTurnUserId,
    int? timeLeft,
    List<String>? users,
    bool? isConnected,
  }) {
    return GameState(
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      timeLeft: timeLeft ?? this.timeLeft,
      users: users ?? this.users,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  String toString() {
    return 'GameState(currentTurnUserId: $currentTurnUserId, timeLeft: $timeLeft, users: $users, isConnected: $isConnected)';
  }
}

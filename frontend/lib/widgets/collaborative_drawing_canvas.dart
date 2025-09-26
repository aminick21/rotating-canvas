import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import '../providers/game_providers.dart';
import '../models/drawing_data.dart';

class CollaborativeDrawingCanvas extends ConsumerStatefulWidget {
  const CollaborativeDrawingCanvas({super.key});

  @override
  ConsumerState<CollaborativeDrawingCanvas> createState() => _CollaborativeDrawingCanvasState();
}

class _CollaborativeDrawingCanvasState extends ConsumerState<CollaborativeDrawingCanvas>
    with TickerProviderStateMixin {
  late DrawingController _drawingController;
  String? _lastTurnUserId;

  // For tracking drawing state
  int _lastContentCount = 0;

  // Store all content (local + remote) to manage through DrawingController
  List<Map<String, dynamic>> _allContents = [];

  // Throttling for performance
  DateTime? _lastTransmissionTime;
  @override
  void initState() {
    super.initState();

    // Initialize drawing controller
    _drawingController = DrawingController();

    // Listen to drawing controller changes for real-time transmission
    _drawingController.addListener(_onDrawingChanged);
  }

  void _onDrawingChanged() {
    final currentUserId = ref.read(currentUserIdProvider);
    final isMyTurn = ref.read(isCurrentUserTurnProvider);

    // Only send drawing data if it's my turn and I have a valid user ID
    if (!isMyTurn || currentUserId == null) return;

    // Throttle transmissions to reduce lag (max 30 FPS)
    final now = DateTime.now();
    if (_lastTransmissionTime != null &&
        now.difference(_lastTransmissionTime!).inMilliseconds < 33) {
      return;
    }

    // Get current drawing data using the JSON list
    final currentJsonList = _drawingController.getJsonList();
    final currentContentCount = currentJsonList.length;

    // Check if there are new contents to send
    if (currentContentCount > _lastContentCount) {
      // Get the latest content(s)
      final newContents = currentJsonList.sublist(_lastContentCount);

      for (final contentJson in newContents) {
        final drawingData = DrawingData.stroke(strokeData: contentJson, userId: currentUserId);

        // Send the drawing data
        ref.read(drawingStrokesProvider.notifier).sendDrawingData(drawingData);
      }

      _lastContentCount = currentContentCount;
      _lastTransmissionTime = now;
    } else if (currentContentCount < _lastContentCount) {
      _lastContentCount = currentContentCount;
    }
  }

  void _applyRemoteDrawingData(DrawingData drawingData) {
    try {
      switch (drawingData.type) {
        case 'stroke':
          if (drawingData.strokeData != null) {
            _addContentFromJson(drawingData.strokeData!);
          }
          break;
        case 'clear':
          _drawingController.clear();
          _lastContentCount = 0;
          _allContents.clear(); // Clear remote contents too
          ref.read(drawingStrokesProvider.notifier).clearCanvas();
          break;
        case 'undo':
          if (_drawingController.canUndo()) {
            _drawingController.undo();
            _lastContentCount = _drawingController.getJsonList().length;
          }
          break;
        case 'redo':
          if (_drawingController.canRedo()) {
            _drawingController.redo();
            _lastContentCount = _drawingController.getJsonList().length;
          }
          break;
      }
    } catch (e) {
      print('Error applying remote drawing data: $e');
    }
  }

  void _addContentFromJson(Map<String, dynamic> jsonData) {
    try {
      // Add the remote content to our tracking list
      _allContents = List<Map<String, dynamic>>.from(_allContents)..add(jsonData);
    } catch (e) {
      print('Error storing remote content: $e');
    }
  }

  @override
  void dispose() {
    _drawingController.removeListener(_onDrawingChanged);
    _drawingController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final isMyTurn = ref.watch(isCurrentUserTurnProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    // Listen for remote drawing data
    ref.listen<List<DrawingData>>(drawingStrokesProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        // New drawing data received
        final newData = next.last;
        // Only apply drawing data from other users
        if (newData.userId != currentUserId) {
          _applyRemoteDrawingData(newData);
        }
      }
    });

    _lastTurnUserId = gameState.currentTurnUserId;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Collaborative Drawing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              final currentUserId = ref.read(currentUserIdProvider);
              if (currentUserId != null) {
                _drawingController.clear();
                final clearData = DrawingData.clear(userId: currentUserId);
                ref.read(drawingStrokesProvider.notifier).sendDrawingData(clearData);
              }
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          // Game info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.green[100] : Colors.grey[200],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Current turn info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMyTurn ? "It's your turn!" : "Waiting for your turn...",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isMyTurn ? Colors.green[800] : Colors.grey[600],
                        ),
                      ),
                      if (gameState.currentTurnUserId != null)
                        Text(
                          'Current player: ${gameState.currentTurnUserId == currentUserId ? 'You' : gameState.currentTurnUserId}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: gameState.timeLeft <= 5 ? Colors.red[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 20,
                        color: gameState.timeLeft <= 5 ? Colors.red[700] : Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${gameState.timeLeft}s',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: gameState.timeLeft <= 5 ? Colors.red[700] : Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Connected users info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  gameState.isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: gameState.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  '${gameState.users.length} player${gameState.users.length != 1 ? 's' : ''} connected',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Drawing canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Base drawing board - shows local content
                    IgnorePointer(
                      ignoring: !isMyTurn,
                      child: DrawingBoard(
                        controller: _drawingController,
                        background: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.white,
                        ),
                        showDefaultActions: true,
                        showDefaultTools: true,
                        boardPanEnabled: false,
                        boardScaleEnabled: false,
                        boardConstrained: true,
                      ),
                    ),
                    // Overlay for showing remote strokes and continuous strokes
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: RemoteStrokesPainter(_allContents, {}),
                          child: Container(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter to render remote strokes
class RemoteStrokesPainter extends CustomPainter {
  final List<Map<String, dynamic>> remoteContents;
  final Map<String, Map<String, dynamic>> activeContinuousStrokes;

  RemoteStrokesPainter(this.remoteContents, this.activeContinuousStrokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Paint completed remote strokes
    for (final content in remoteContents) {
      _paintFromDrawingBoardJson(canvas, content);
    }

    // Paint active continuous strokes
    for (final strokeData in activeContinuousStrokes.values) {
      _paintContinuousStroke(canvas, strokeData);
    }
  }

  void _paintContinuousStroke(Canvas canvas, Map<String, dynamic> strokeData) {
    try {
      final points = strokeData['points'] as List?;
      final paintData = strokeData['paint'] as Map<String, dynamic>?;

      if (points == null || points.isEmpty || paintData == null) return;

      // Create paint from the data
      final paint =
          Paint()
            ..color = Color(paintData['color'] ?? Colors.black.value)
            ..strokeWidth = paintData['strokeWidth']?.toDouble() ?? 2.0
            ..style = PaintingStyle.values[paintData['style'] ?? 1]
            ..strokeCap = StrokeCap.values[paintData['strokeCap'] ?? 1]
            ..strokeJoin = StrokeJoin.values[paintData['strokeJoin'] ?? 1]
            ..isAntiAlias = paintData['isAntiAlias'] ?? false;

      // Convert points to Offset objects
      final offsetPoints = <Offset>[];
      for (final point in points) {
        final dx = point['dx']?.toDouble() ?? 0.0;
        final dy = point['dy']?.toDouble() ?? 0.0;
        offsetPoints.add(Offset(dx, dy));
      }

      if (offsetPoints.isEmpty) return;

      // Draw the continuous stroke
      final path = Path();
      path.moveTo(offsetPoints.first.dx, offsetPoints.first.dy);

      for (int i = 1; i < offsetPoints.length; i++) {
        final current = offsetPoints[i];

        if (i == offsetPoints.length - 1 || offsetPoints.length == 2) {
          // Last point or only two points - draw line
          path.lineTo(current.dx, current.dy);
        } else {
          // Use quadratic bezier for smooth curves
          final next = offsetPoints[i + 1];
          final controlPoint = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
          path.quadraticBezierTo(current.dx, current.dy, controlPoint.dx, controlPoint.dy);
        }
      }

      canvas.drawPath(path, paint);
    } catch (e) {
      print('Error painting continuous stroke: $e');
    }
  }

  void _paintFromDrawingBoardJson(Canvas canvas, Map<String, dynamic> strokeData) {
    try {
      final type = strokeData['type'] as String?;
      final paintData = strokeData['paint'] as Map<String, dynamic>?;

      if (paintData == null) return;

      // Create paint from the JSON data
      final paint =
          Paint()
            ..color = Color(paintData['color'] ?? Colors.black.value)
            ..strokeWidth = paintData['strokeWidth']?.toDouble() ?? 2.0
            ..style = PaintingStyle.values[paintData['style'] ?? 1]
            ..strokeCap = StrokeCap.values[paintData['strokeCap'] ?? 1]
            ..strokeJoin = StrokeJoin.values[paintData['strokeJoin'] ?? 1]
            ..isAntiAlias = paintData['isAntiAlias'] ?? false;

      // Handle different drawing types
      switch (type) {
        case 'SimpleLine':
          _paintLine(canvas, strokeData, paint);
          break;
        case 'SmoothLine':
        case 'Eraser':
          _paintSmoothLine(canvas, strokeData, paint);
          break;
        case 'StraightLine':
          _paintStraightLine(canvas, strokeData, paint);
          break;
        case 'Rectangle':
          _paintRectangle(canvas, strokeData, paint);
          break;
        case 'Circle':
          _paintCircle(canvas, strokeData, paint);
          break;
      }
    } catch (e) {
      // Only log actual errors
      print('Error painting remote stroke: $e');
    }
  }

  void _paintSmoothLine(Canvas canvas, Map<String, dynamic> data, Paint paint) {
    final points = data['points'] as List?;
    final strokeWidthList = data['strokeWidthList'] as List?;

    if (points == null || points.isEmpty) return;

    // Convert points to Offset objects
    final offsetPoints = <Offset>[];
    for (final point in points) {
      final dx = point['dx']?.toDouble() ?? 0.0;
      final dy = point['dy']?.toDouble() ?? 0.0;
      offsetPoints.add(Offset(dx, dy));
    }

    if (offsetPoints.length < 2) {
      // Single point - draw a dot
      canvas.drawCircle(offsetPoints.first, paint.strokeWidth / 2, paint);
      return;
    }

    // Create a smooth path through the points
    final path = Path();
    path.moveTo(offsetPoints.first.dx, offsetPoints.first.dy);

    if (offsetPoints.length == 2) {
      // Just two points - draw a straight line
      path.lineTo(offsetPoints.last.dx, offsetPoints.last.dy);
    } else {
      // Multiple points - create smooth curves (optimized)
      for (int i = 1; i < offsetPoints.length; i++) {
        final current = offsetPoints[i];

        if (i == offsetPoints.length - 1) {
          // Last point - draw line to it
          path.lineTo(current.dx, current.dy);
        } else {
          // Use quadratic bezier for smooth curves
          final next = offsetPoints[i + 1];
          final controlPoint = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
          path.quadraticBezierTo(current.dx, current.dy, controlPoint.dx, controlPoint.dy);
        }
      }
    }

    // Handle variable stroke width (use first value for performance)
    if (strokeWidthList != null && strokeWidthList.isNotEmpty) {
      final firstStrokeWidth = strokeWidthList.first?.toDouble() ?? paint.strokeWidth;
      paint.strokeWidth = firstStrokeWidth;
    }

    canvas.drawPath(path, paint);
  }

  void _paintLine(Canvas canvas, Map<String, dynamic> data, Paint paint) {
    final pathData = data['path'] as Map<String, dynamic>?;
    if (pathData == null) return;

    final steps = pathData['steps'] as List?;
    if (steps == null || steps.isEmpty) return;

    final path = Path();

    for (final step in steps) {
      final stepType = step['type'] as String?;
      final x = step['x']?.toDouble() ?? 0.0;
      final y = step['y']?.toDouble() ?? 0.0;

      switch (stepType) {
        case 'moveTo':
          path.moveTo(x, y);
          break;
        case 'lineTo':
          path.lineTo(x, y);
          break;
        case 'cubicTo':
          final x1 = step['x1']?.toDouble() ?? 0.0;
          final y1 = step['y1']?.toDouble() ?? 0.0;
          final x2 = step['x2']?.toDouble() ?? 0.0;
          final y2 = step['y2']?.toDouble() ?? 0.0;
          path.cubicTo(x1, y1, x2, y2, x, y);
          break;
        case 'quadraticBezierTo':
          final x1 = step['x1']?.toDouble() ?? 0.0;
          final y1 = step['y1']?.toDouble() ?? 0.0;
          path.quadraticBezierTo(x1, y1, x, y);
          break;
      }
    }

    canvas.drawPath(path, paint);
  }

  void _paintStraightLine(Canvas canvas, Map<String, dynamic> data, Paint paint) {
    final startPoint = data['startPoint'] as Map<String, dynamic>?;
    final endPoint = data['endPoint'] as Map<String, dynamic>?;

    if (startPoint == null || endPoint == null) return;

    final start = Offset(startPoint['dx']?.toDouble() ?? 0.0, startPoint['dy']?.toDouble() ?? 0.0);
    final end = Offset(endPoint['dx']?.toDouble() ?? 0.0, endPoint['dy']?.toDouble() ?? 0.0);

    canvas.drawLine(start, end, paint);
  }

  void _paintRectangle(Canvas canvas, Map<String, dynamic> data, Paint paint) {
    final startPoint = data['startPoint'] as Map<String, dynamic>?;
    final endPoint = data['endPoint'] as Map<String, dynamic>?;

    if (startPoint == null || endPoint == null) return;

    final start = Offset(startPoint['dx']?.toDouble() ?? 0.0, startPoint['dy']?.toDouble() ?? 0.0);
    final end = Offset(endPoint['dx']?.toDouble() ?? 0.0, endPoint['dy']?.toDouble() ?? 0.0);

    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, paint);
  }

  void _paintCircle(Canvas canvas, Map<String, dynamic> data, Paint paint) {
    final startPoint = data['startPoint'] as Map<String, dynamic>?;
    final endPoint = data['endPoint'] as Map<String, dynamic>?;

    if (startPoint == null || endPoint == null) return;

    final start = Offset(startPoint['dx']?.toDouble() ?? 0.0, startPoint['dy']?.toDouble() ?? 0.0);
    final end = Offset(endPoint['dx']?.toDouble() ?? 0.0, endPoint['dy']?.toDouble() ?? 0.0);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final radius = (end - start).distance / 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RemoteStrokesPainter oldDelegate) {
    // Repaint if completed strokes or active continuous strokes changed
    return remoteContents.length != oldDelegate.remoteContents.length ||
        activeContinuousStrokes.length != oldDelegate.activeContinuousStrokes.length;
  }
}

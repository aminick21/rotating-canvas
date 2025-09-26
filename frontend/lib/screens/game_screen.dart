import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import '../widgets/collaborative_drawing_canvas.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default server URL - update this to match your backend server
    _serverUrlController.text = 'http://localhost:3000';
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);

    print('[GameScreen] Build called - gameState.isConnected: ${gameState.isConnected}');
    print('[GameScreen] Full gameState: $gameState');

    if (!gameState.isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Collaborative Drawing'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.brush, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Collaborative Drawing!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect to a server to start drawing with others.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://localhost:3001',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final serverUrl = _serverUrlController.text.trim();
                  if (serverUrl.isNotEmpty) {
                    ref.read(gameStateProvider.notifier).connect(serverUrl);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Please enter a server URL')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Connect to Server', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Make sure your backend server is running on the specified URL.',
                style: TextStyle(fontSize: 14, color: Colors.orange, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const CollaborativeDrawingCanvas();
  }
}

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'secrets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Senthil's AI",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        primaryColor: Colors.greenAccent,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _userInput = TextEditingController();
  late GenerativeModel model;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showWelcomeScreen = true;
  final Random _random = Random();
  
  // Advanced response variation system
  final Map<String, List<String>> _previousResponses = {};
  
  // Welcome messages variations
  final List<String> _welcomeMessages = [
    "How can I assist you today? I can help with recipes, answer questions, provide information, or just chat about anything you're interested in.",
    "Hello! I'm here to help. What would you like to know or discuss today?",
    "Welcome! I'm ready to assist with information, creative content, or a friendly conversation.",
    "Greetings! How may I help you today? Feel free to ask me anything.",
    "Hi there! I'm your AI assistant. What can I help you with today?"
  ];

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: API_KEY);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getRandomWelcomeMessage() {
    return _welcomeMessages[_random.nextInt(_welcomeMessages.length)];
  }

  void _startConversation(String prompt) {
    setState(() {
      _showWelcomeScreen = false;
      _messages.add(Message(
        isUser: false,
        message: _getRandomWelcomeMessage(),
        date: DateTime.now(),
      ));
      _userInput.text = prompt;
    });
    
    if (prompt.isNotEmpty) {
      sendMessage();
    }
  }

  // Generate a fingerprint for a query to identify similar questions
  String _generateQueryFingerprint(String query) {
    // Remove punctuation, lowercase, and trim
    String normalized = query.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Get key words (words longer than 3 chars)
    List<String> words = normalized.split(' ')
        .where((word) => word.length > 3)
        .toList();
    
    // Sort words to catch rearrangements of the same question
    words.sort();
    
    return words.join(' ');
  }

  Future<void> sendMessage() async {
    final message = _userInput.text.trim();
    if (message.isEmpty || _isLoading) return;

    // If this is the first message, add the initial AI response
    if (_showWelcomeScreen) {
      setState(() {
        _showWelcomeScreen = false;
        _messages.add(Message(
          isUser: false,
          message: _getRandomWelcomeMessage(),
          date: DateTime.now(),
        ));
      });
    }

    setState(() {
      _messages.add(Message(isUser: true, message: message, date: DateTime.now()));
      _userInput.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Advanced response variation system
      String fingerprint = _generateQueryFingerprint(message);
      bool isRepeatedQuery = _previousResponses.containsKey(fingerprint) && 
                             _previousResponses[fingerprint]!.isNotEmpty;
      
      // Create a prompt that ensures variety
      String enhancedPrompt;
      if (isRepeatedQuery) {
        // Create a prompt that specifically asks for a different response
        enhancedPrompt = """
${message}

[SYSTEM INSTRUCTION: This is a repeated question. Please provide a completely different response than any of these previous responses:
${_previousResponses[fingerprint]!.join('\n\n')}

Be creative and approach the question from a new angle or with different information.]
""";
      } else {
        enhancedPrompt = message;
      }
      
      // Add temperature parameter for more creative responses
      final generationConfig = GenerationConfig(
        temperature: 0.7 + (_random.nextDouble() * 0.3), // Between 0.7 and 1.0
        topK: 40,
        topP: 0.95,
      );
      
      // Generate content with the enhanced prompt
      final response = await model.generateContent(
        [Content.text(enhancedPrompt)],
        generationConfig: generationConfig,
      );
      
      String responseText = response.text ?? "No response received.";
      
      // Store this response to avoid repetition
      if (!_previousResponses.containsKey(fingerprint)) {
        _previousResponses[fingerprint] = [];
      }
      _previousResponses[fingerprint]!.add(responseText);
      
      // Limit stored responses to prevent memory issues
      if (_previousResponses[fingerprint]!.length > 3) {
        _previousResponses[fingerprint]!.removeAt(0);
      }
      
      setState(() {
        _messages.add(Message(
          isUser: false,
          message: responseText,
          date: DateTime.now(),
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message(
          isUser: false,
          message: "Error: ${e.toString()}",
          date: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Senthil's AI",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        actions: [
          CircleAvatar(
            backgroundColor: Colors.amber,
            child: const Text(
              "SK",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _showWelcomeScreen 
                ? _buildWelcomeScreen()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildLoadingIndicator();
                      }
                      final message = _messages[index];
                      return Messages(
                        isUser: message.isUser,
                        message: message.message,
                        date: DateFormat('HH:mm').format(message.date),
                      );
                    },
                  ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Welcome',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Text(
            'What can I help with?',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[300],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSuggestionButton(
                "Find a recipe",
                Icons.restaurant,
                () => _startConversation("I need a recipe for dinner tonight"),
              ),
              _buildSuggestionButton(
                "Ask me anything",
                Icons.psychology,
                () => _startConversation(""),
              ),
              _buildSuggestionButton(
                "Get information",
                Icons.lightbulb,
                () => _startConversation("Tell me about"),
              ),
              _buildSuggestionButton(
                "Create content",
                Icons.create,
                () => _startConversation("Help me write"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionButton(String text, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
            color: Colors.grey[400],
          ),
          Expanded(
            child: TextField(
              controller: _userInput,
              onSubmitted: (_) => sendMessage(),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Message here....',
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : Colors.greenAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.black,
              ),
              onPressed: _isLoading ? null : sendMessage,
              tooltip: 'Send message',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: Colors.greenAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class Message {
  final bool isUser;
  final String message;
  final DateTime date;

  Message({required this.isUser, required this.message, required this.date});
}

class Messages extends StatelessWidget {
  final bool isUser;
  final String message;
  final String date;

  const Messages({
    super.key,
    required this.isUser,
    required this.message,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueGrey[800] : Colors.grey[800],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                const Spacer(),
                if (!isUser) // Only show copy button for AI responses
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied to clipboard'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    tooltip: 'Copy to clipboard',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
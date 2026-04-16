import 'package:flutter/material.dart';
import '../widgets/nlp_chatbot_widget.dart' show ChatMessage;

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [
    ChatMessage(text: "Ask me to find products! (e.g. sugar free)", isUser: false)
  ];

  List<ChatMessage> get messages => _messages;

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _messages.add(ChatMessage(text: "Ask me to find products! (e.g. sugar free)", isUser: false));
    notifyListeners();
  }
}

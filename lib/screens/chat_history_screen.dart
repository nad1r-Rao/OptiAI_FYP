// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/chat_provider.dart';

// class ChatHistoryScreen extends StatefulWidget {
//   const ChatHistoryScreen({super.key});

//   @override
//   State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
// }

// class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
//   @override
//   void initState() {
//     super.initState();

//     // Load chat history only when this screen opens
//     Future.microtask(() {
//       context.read<ChatProvider>().loadChatHistory(show: true, force: true);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final messages = context.watch<ChatProvider>().messages;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chat History'),
//       ),
//       body: messages.isEmpty
//           ? const Center(child: Text('No chat history available.'))
//           : ListView.builder(
//               itemCount: messages.length,
//               itemBuilder: (context, index) {
//                 final msg = messages[index];
//                 final isUser = msg.isUser;
//                 final hasImage = msg.imageBytes != null;

//                 return Container(
//                   alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   child: Column(
//                     crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                     children: [
//                       if (msg.message != null)
//                         Container(
//                           decoration: BoxDecoration(
//                             color: isUser ? Colors.blue[200] : Colors.grey[300],
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           padding: const EdgeInsets.all(10),
//                           child: Text(
//                             msg.message!,
//                             style: const TextStyle(fontSize: 16),
//                           ),
//                         ),
//                       if (hasImage)
//                         Container(
//                           margin: const EdgeInsets.only(top: 5),
//                           child: Image.memory(msg.imageBytes!, height: 150),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }

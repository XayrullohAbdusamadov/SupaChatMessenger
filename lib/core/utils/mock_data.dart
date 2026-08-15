import '../../data/models/user_profile.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/models/chat_message.dart';

class MockData {
  static final UserProfile currentUser = UserProfile(
    id: 'user-me-001',
    username: 'akbar_dev',
    fullName: 'Sizning Ismingiz',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80',
    about: 'Hey there! I am using SupaChat.',
    role: 'Lead Mobile Engineer',
    isOnline: true,
  );

  static final List<UserProfile> contacts = [
    UserProfile(
      id: 'user-lola',
      username: 'lola_k',
      fullName: 'Lola Karimova',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80',
      about: 'Flutter & Product Designer',
      role: 'Product Designer',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-abbos',
      username: 'abbos_sh',
      fullName: 'Abbos Sharipov',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80',
      about: 'Building real-time systems 🚀',
      role: 'Backend Engineer',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-aziz',
      username: 'aziz_dev',
      fullName: 'Aziz Rahimov',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80',
      about: 'Coding Flutter apps day & night',
      role: 'Software Engineer',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-dilnoza',
      username: 'dilnoza_ui',
      fullName: 'Dilnoza Aliyeva',
      avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&auto=format&fit=crop&q=80',
      about: 'Crafting clean UI/UX experiences ✨',
      role: 'UI/UX Designer',
      isOnline: false,
    ),
    UserProfile(
      id: 'user-sardor',
      username: 'sardor_pm',
      fullName: 'Sardor Mahmudov',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80',
      about: 'Agile & Scrum Evangelist',
      role: 'Project Manager',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-elena',
      username: 'elena_r',
      fullName: 'Elena Rodriguez',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&auto=format&fit=crop&q=80',
      about: 'Design Systems lead',
      role: 'Design Lead',
      isOnline: false,
    ),
    UserProfile(
      id: 'user-david',
      username: 'david_c',
      fullName: 'David Chen',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&auto=format&fit=crop&q=80',
      about: 'Cloud Architecture & DevOps',
      role: 'DevOps Specialist',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-anna',
      username: 'anna_s',
      fullName: 'Anna Schmidt',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=80',
      about: 'Mobile QA engineer',
      role: 'QA Engineer',
      isOnline: false,
    ),
    UserProfile(
      id: 'user-sarah',
      username: 'sarah_m',
      fullName: 'Sarah Miller',
      avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&auto=format&fit=crop&q=80',
      about: 'Life is good 🌿',
      role: 'Marketing Lead',
      isOnline: true,
    ),
    UserProfile(
      id: 'user-michael',
      username: 'michael_b',
      fullName: 'Michael Brown',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=300&auto=format&fit=crop&q=80',
      about: 'Exploring AI & Web3',
      role: 'Full Stack Dev',
      isOnline: true,
    ),
  ];

  static List<ChatConversation> getInitialChats() {
    return [
      ChatConversation(
        id: 'chat-lola',
        isGroup: false,
        name: 'Lola Karimova',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80',
        participants: [
          contacts[0], // Lola
        ],
        lastMessageText: '🎤 Ovozli xabar (0:14)',
        lastMessageType: MessageType.voice,
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 0,
      ),
      ChatConversation(
        id: 'chat-abbos',
        isGroup: false,
        name: 'Abbos Sharipov',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80',
        participants: [
          contacts[1],
        ],
        lastMessageText: '📷 Rasm yuborildi',
        lastMessageType: MessageType.image,
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 25)),
        unreadCount: 1,
      ),
      ChatConversation(
        id: 'chat-group-frontend',
        isGroup: true,
        name: 'Frontend Team Group',
        avatarUrl: null, // will show group icon / initials
        participants: [
          contacts[0],
          contacts[2],
          contacts[3],
        ],
        lastMessageText: 'Javob: Ok, kutaman',
        lastMessageType: MessageType.text,
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        unreadCount: 2,
      ),
      ChatConversation(
        id: 'chat-elena',
        isGroup: false,
        name: 'Elena Rodriguez',
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&auto=format&fit=crop&q=80',
        participants: [
          contacts[5],
        ],
        lastMessageText: 'Thanks for the update!',
        lastMessageType: MessageType.text,
        lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
      ChatConversation(
        id: 'chat-david',
        isGroup: false,
        name: 'David Chen',
        avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&auto=format&fit=crop&q=80',
        participants: [
          contacts[6],
        ],
        lastMessageText: 'Typing...',
        lastMessageType: MessageType.text,
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 2)),
        unreadCount: 0,
        isTyping: true,
        typingUserName: 'David',
      ),
      ChatConversation(
        id: 'chat-group-marketing',
        isGroup: true,
        name: 'Marketing Sync',
        avatarUrl: null,
        participants: [
          contacts[4],
          contacts[8],
        ],
        lastMessageText: "Let's review the new assets tomorrow.",
        lastMessageType: MessageType.text,
        lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: 0,
      ),
      ChatConversation(
        id: 'chat-anna',
        isGroup: false,
        name: 'Anna Schmidt',
        avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=80',
        participants: [
          contacts[7],
        ],
        lastMessageText: "I'll send the files over by noon.",
        lastMessageType: MessageType.text,
        draftMessage: "I'll send the files over by",
        lastMessageAt: DateTime.now().subtract(const Duration(days: 4)),
        unreadCount: 0,
      ),
    ];
  }

  static List<ChatMessage> getLolaMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'msg-1',
        chatId: 'chat-lola',
        senderId: 'user-lola',
        messageType: MessageType.text,
        content: "Salom, loyiha bo'yicha TZ tayyormi?",
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      ChatMessage(
        id: 'msg-2',
        chatId: 'chat-lola',
        senderId: 'user-me-001',
        messageType: MessageType.text,
        content: "Ha, tayyor. Hozir tashlayman.",
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(minutes: 32)),
      ),
      ChatMessage(
        id: 'msg-3',
        chatId: 'chat-lola',
        senderId: 'user-me-001',
        messageType: MessageType.image,
        content: "Loyiha_TZ_v1.pdf",
        mediaUrl: 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=800&auto=format&fit=crop&q=80',
        fileName: 'Loyiha_TZ_v1.pdf',
        mediaSize: 2450000,
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'msg-4',
        chatId: 'chat-lola',
        senderId: 'user-lola',
        messageType: MessageType.voice,
        content: 'Voice message',
        voiceDuration: 14, // 0:14
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
    ];
  }
}

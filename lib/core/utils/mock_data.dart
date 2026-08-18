import '../../data/models/user_profile.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/models/chat_message.dart';

class MockData {
  static final UserProfile currentUser = UserProfile(
    id: 'user-default',
    username: 'foydalanuvchi',
    fullName: 'Foydalanuvchi',
    avatarUrl: null,
    about: 'Hey there! I am using SupaChat.',
    isOnline: true,
  );

  static final List<UserProfile> contacts = [];

  static List<ChatConversation> getInitialChats() => [];

  static List<ChatMessage> getLolaMessages() => [];
}

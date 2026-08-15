import 'package:intl/intl.dart';

class DateFormatter {
  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && now.day == dateTime.day) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dateTime.day)) {
      return 'Kecha'; // Yesterday
    } else if (difference.inDays < 7) {
      // Day of week in Uzbek/Short
      switch (dateTime.weekday) {
        case 1:
          return 'Dush';
        case 2:
          return 'Sesh';
        case 3:
          return 'Chor';
        case 4:
          return 'Pay';
        case 5:
          return 'Juma';
        case 6:
          return 'Shan';
        case 7:
          return 'Yak';
        default:
          return DateFormat('E').format(dateTime);
      }
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

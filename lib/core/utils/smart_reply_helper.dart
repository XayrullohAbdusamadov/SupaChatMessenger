import 'dart:math';
import '../../data/models/chat_message.dart';

class SmartReplyHelper {
  static final Random _random = Random();

  static String generateReply({
    required ChatMessage userMessage,
    required String contactName,
  }) {
    final text = userMessage.content.toLowerCase().trim();
    final firstName = contactName.split(' ').first;

    // 1. If voice message
    if (userMessage.messageType == MessageType.voice) {
      final voiceReplies = [
        "Ovozli xabaringizni eshitdim! Juda yaxshi fikr, kelishdik 👍",
        "Ovozingizni eshitganimdan xursandman! Hozir biroz bandman, tez orada batafsil yozaman 🤝",
        "Tushundim! Aytganingizdek qilamiz, rahmat.",
        "Ovozli xabar uchun rahmat, barchasini tushundim! 🔥",
      ];
      return voiceReplies[_random.nextInt(voiceReplies.length)];
    }

    // 2. If image message
    if (userMessage.messageType == MessageType.image) {
      final imageReplies = [
        "Juda ajoyib rasm ekan! Sifati ham zo'r chiqibdi 🔥📸",
        "Kadr ajoyib olinibdi! Menga juda yoqdi ✨",
        "Rasm uchun rahmat, o'zimga saqlab qo'ydim 👍",
        "Zo'r chiqibdi! Qayerda rasmga tushdingiz? 😊",
      ];
      return imageReplies[_random.nextInt(imageReplies.length)];
    }

    // 3. If video message
    if (userMessage.messageType == MessageType.video) {
      final videoReplies = [
        "Videoni tomosha qildim, juda qiziqarli chiqibdi! 🎥🔥",
        "Zo'r video lavha bo'libdi! Rahmat ulashganingiz uchun 👏",
        "Video sifati ajoyib! Kayfiyatni ko'tardi 😄",
      ];
      return videoReplies[_random.nextInt(videoReplies.length)];
    }

    // 4. If story reply
    if (text.contains('story') || text.contains('✨') || text.contains('❤️') || text.contains('🔥')) {
      final storyReplies = [
        "Storyimga e'tibor berganingiz uchun katta rahmat! 😊✨",
        "Rahmat! Sizning ham storylaringizni kuzatib boraman 🔥",
        "Yoqqanidan xursandman! Kayfiyatingiz a'lo bo'lsin 💫",
      ];
      return storyReplies[_random.nextInt(storyReplies.length)];
    }

    // 5. If sticker or pure emoji
    if (text.length <= 4 && (text.contains('😊') || text.contains('😂') || text.contains('👍') || text.contains('🔥') || text.contains('❤️'))) {
      final emojiReplies = [
        "Ajoyib stiker! Kayfiyatni ko'tardi 😄🔥",
        "Zo'r emodzi! 👍✨",
        "Siz bilan suhbatlashish doim yoqimli! 😊",
        "🔥🔥🔥",
      ];
      return emojiReplies[_random.nextInt(emojiReplies.length)];
    }

    // 6. Greetings
    if (text.contains('salom') || text.contains('assalom') || text.contains('alaykum') || text.contains('privet') || text.contains('hello')) {
      final greetings = [
        "Assalomu alaykum! Yaxshimisiz? Ishlaringiz yaxshi ketyaptimi?",
        "Va alaykum assalom! Kuningiz xayrli va unumli o'tsin! Qanday yangiliklar bor?",
        "Salom! Hol-ahvollar qalay? Sizni ko'rganimdan xursandman 😊",
        "Salom! Ishlar, o'qishlar bilan charchamayapsizmi?",
      ];
      return greetings[_random.nextInt(greetings.length)];
    }

    // 7. How are you / Status
    if (text.contains('qalay') || text.contains('qalesiz') || text.contains('tinchmi') || text.contains('yaxshimisiz') || text.contains('yaxshimi')) {
      final statusReplies = [
        "Rahmat, hammasi a'lo darajada! O'zingizda nima gaplar?",
        "Xudoga shukur, yaxshiman. Yangi loyihalar bilan bandmiz. Sizda nima yangiliklar?",
        "Hammasi tinch, rahmat! O'zingiz qandaysiz, sog'-salomatmisiz?",
        "Juda yaxshi, rahmat so'raganingiz uchun! Oila va ishlaringiz tinchmi?",
      ];
      return statusReplies[_random.nextInt(statusReplies.length)];
    }

    // 8. Location / What are you doing
    if (text.contains('qayerdasiz') || text.contains('qattasiz') || text.contains('nima qilyapsiz') || text.contains('ishdami') || text.contains('qattasan')) {
      final actionReplies = [
        "Hozir ofisdaman, muhim vazifalarni yakunlayapman. Siz qayerdasiz?",
        "Ishxonadaman, yangi funksiyalarni tekshiryapman. Biror zarur ish bormidi?",
        "Hozir biroz bo'sh vaqtim bor, suhbatlashishga tayyorman! Siz qayerdasiz?",
        "Shahardaman, ishlarni bitirib qaytyapman. Siz nimalar bilan bandsiz?",
      ];
      return actionReplies[_random.nextInt(actionReplies.length)];
    }

    // 9. Meeting / Time
    if (text.contains('qachon') || text.contains('uchrashamiz') || text.contains('ko\'rishamiz') || text.contains('vaqtingiz bormi')) {
      final meetReplies = [
        "Bugun kechroq yoki ertaga tushdan so'ng bemalol uchrashsak bo'ladi! Qaysi vaqt sizga ma'qul?",
        "Albatta, bir choy ichib gaplashaylik! Ertaga soat 17:00 da vaqtingiz bormi?",
        "Juda yaxshi bo'lardi! Aniq vaqtini kelishib olsak bo'ladi.",
      ];
      return meetReplies[_random.nextInt(meetReplies.length)];
    }

    // 10. Gratitude / Goodbye
    if (text.contains('rahmat') || text.contains('tashakkur') || text.contains('spasibo') || text.contains('raxmat')) {
      final thanksReplies = [
        "Arzimaydi, doim xizmatingizdaman! 😊",
        "Sizga ham katta rahmat! Biror yordam kerak bo'lsa bemalol ayting 👍",
        "Har doim jon deb yordam beraman!",
      ];
      return thanksReplies[_random.nextInt(thanksReplies.length)];
    }

    if (text.contains('xayr') || text.contains('hayr') || text.contains('yaxshi dam oling') || text.contains('ko\'rishguncha')) {
      return "Xayr! Yaxshi dam oling, o'zingizni ehtiyot qiling! Ko'rishguncha 👋";
    }

    // 11. General intelligent fallback
    final generalReplies = [
      "Fikringizga to'liq qo'shilaman! Bu masala bo'yicha yana gaplashamiz 👍",
      "Tushundim, juda to'g'ri aytdingiz. $firstName, buni tez orada amalga oshiramiz!",
      "Ajoyib! Buni albatta hisobga olaman. Boshqa yangiliklar bormi?",
      "Zo'r ma'lumot bo'ldi, rahmat! Siz bilan gaplashish doim yoqimli 😊",
    ];
    return generalReplies[_random.nextInt(generalReplies.length)];
  }
}

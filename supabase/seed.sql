-- ==============================================================================
-- SUPACHAT MESSENGER - INITIAL SEED DATA (Test & Demo ma'lumotlar)
-- ==============================================================================
-- Ushbu skript Supabase bazasiga boshlang'ich test akkauntlari va tizim botini kiritish uchun xizmat qiladi.
-- Barcha ID lar xatosiz ishlashi uchun to'liq standart UUID formatida berilgan.

-- 1. TIZIM BOTI VA TEST FOYDALANUVCHILARI (Demo Profiles)
INSERT INTO public.profiles (id, username, full_name, avatar_url, about, role, is_online, last_seen)
VALUES 
  (
    '00000000-0000-4000-a000-000000000001',
    'supachat_bot',
    'SupaChat Assistant 🤖',
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=150&auto=format&fit=crop&q=80',
    'SupaChat rasmiy yordamchi boti. Savollaringiz bormi?',
    'Official Bot',
    true,
    NOW()
  ),
  (
    '00000000-0000-4000-a000-000000000002',
    'admin_dev',
    'SupaChat Developer',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
    'Welcome to SupaChat Messenger! Enjoy fast and real-time messaging.',
    'System Admin',
    true,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  about = EXCLUDED.about,
  avatar_url = EXCLUDED.avatar_url,
  is_online = EXCLUDED.is_online;

-- 2. RASMIY GURUH (Welcome Community Group)
INSERT INTO public.chats (id, is_group, group_name, group_avatar, created_by, last_message_text, last_message_type, last_message_at)
VALUES 
  (
    '00000000-0000-4000-a000-000000000010',
    true,
    'SupaChat Community 🌟',
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150&auto=format&fit=crop&q=80',
    '00000000-0000-4000-a000-000000000002',
    'Xush kelibsiz! Bu SupaChat umumiy hamjamiyat guruhi.',
    'text',
    NOW()
  )
ON CONFLICT (id) DO NOTHING;

-- 3. GURUH ISHTIROKCHILARI (Community Participants)
INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
VALUES 
  ('00000000-0000-4000-a000-000000000010', '00000000-0000-4000-a000-000000000002', 'admin', 0),
  ('00000000-0000-4000-a000-000000000010', '00000000-0000-4000-a000-000000000001', 'member', 0)
ON CONFLICT (chat_id, user_id) DO NOTHING;

-- 4. BOSHISHTIROKCHI XABARI (Welcome Message)
INSERT INTO public.messages (id, chat_id, sender_id, message_type, content, status, created_at)
VALUES 
  (
    '00000000-0000-4000-a000-000000000100',
    '00000000-0000-4000-a000-000000000010',
    '00000000-0000-4000-a000-000000000002',
    'text',
    'SupaChat Messenger ilovasiga xush kelibsiz! 👋 Ushbu guruhda barcha foydalanuvchilar bir-birlari bilan muloqot qilishlari mumkin.',
    'sent',
    NOW()
  )
ON CONFLICT (id) DO NOTHING;

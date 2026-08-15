-- ==============================================================================
-- SUPACHAT MESSENGER - INITIAL SEED DATA
-- ==============================================================================
-- Ushbu skript Supabase Dashboard SQL Editorida ishga tushirilsa,
-- demo foydalanuvchilar, chatlar va xabarlarni avtomatik kiritadi.

-- 0. CHEKLOVLARNI TO'G'RILASH (Foreign Key va Ustunlarni sozlash)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT DEFAULT 'Hey there! I am using SupaChat.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- 1. DEMO PROFILLAR
INSERT INTO public.profiles (id, username, full_name, avatar_url, about, role, is_online)
VALUES
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'akbar_dev', 'Sizning Ismingiz', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80', 'Hey there! I am using SupaChat.', 'Lead Mobile Engineer', true),
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'lola_k', 'Lola Karimova', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80', 'Flutter & Product Designer', 'Product Designer', true),
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'abbos_sh', 'Abbos Sharipov', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80', 'Building real-time systems 🚀', 'Backend Engineer', true),
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'aziz_dev', 'Aziz Rahimov', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80', 'Coding Flutter apps day & night', 'Software Engineer', true),
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15', 'dilnoza_ui', 'Dilnoza Aliyeva', 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&auto=format&fit=crop&q=80', 'Crafting clean UI/UX experiences ✨', 'UI/UX Designer', false),
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a16', 'sardor_pm', 'Sardor Mahmudov', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80', 'Agile & Scrum Evangelist', 'Project Manager', true)
ON CONFLICT (id) DO NOTHING;

-- 2. DEMO CHATLAR
INSERT INTO public.chats (id, is_group, group_name, group_avatar, created_by, last_message_text, last_message_type)
VALUES
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', false, 'Lola Karimova', NULL, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '🎤 Ovozli xabar (0:14)', 'voice'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', false, 'Abbos Sharipov', NULL, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '📷 Rasm yuborildi', 'image'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', true, 'Frontend Team Group', NULL, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Javob: Ok, kutaman', 'text'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b14', true, 'Marketing Sync', NULL, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Let''s review the new assets tomorrow.', 'text')
ON CONFLICT (id) DO NOTHING;

-- 3. CHAT ISHTIROKCHILARI
INSERT INTO public.chat_participants (chat_id, user_id, role)
VALUES
  -- Lola chat
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'member'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'member'),
  -- Abbos chat
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'member'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b12', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'member'),
  -- Frontend Group
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'admin'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'member'),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b13', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'member')
ON CONFLICT (chat_id, user_id) DO NOTHING;

-- 4. LOLA BILAN YOZISHMALAR
INSERT INTO public.messages (id, chat_id, sender_id, message_type, content, status, voice_duration, media_url, media_size)
VALUES
  ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'text', 'Salom, loyiha bo''yicha TZ tayyormi?', 'read', NULL, NULL, NULL),
  ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c12', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'text', 'Ha, tayyor. Hozir tashlayman.', 'read', NULL, NULL, NULL),
  ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c13', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'image', 'Loyiha_TZ_v1.pdf', 'read', NULL, 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?w=800&auto=format&fit=crop&q=80', 2450000),
  ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c14', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'voice', 'Voice message', 'read', 14, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

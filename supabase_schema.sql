-- ==============================================================================
-- SUPACHAT MESSENGER - SUPABASE DATABASE & STORAGE SCHEMA
-- ==============================================================================
-- Run this SQL in your Supabase Dashboard: SQL Editor -> New Query -> Run.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. FOYDALANUVCHILAR PROFILLARI JADVALI (profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    about TEXT DEFAULT 'Hey there! I am using SupaChat.',
    role VARCHAR(100),
    phone_number VARCHAR(30),
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ustunlar mavjudligini tekshirib qo'shish (eski jadvallar uchun):
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number VARCHAR(30);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT DEFAULT 'Hey there! I am using SupaChat.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 3. CHATLAR VA GURUHLAR JADVALI (chats)
CREATE TABLE IF NOT EXISTS public.chats (
    id TEXT PRIMARY KEY,
    is_group BOOLEAN DEFAULT false,
    group_name VARCHAR(100),
    group_avatar TEXT,
    created_by TEXT,
    admin_ids TEXT[] DEFAULT '{}',
    blocked_member_ids TEXT[] DEFAULT '{}',
    last_message_text TEXT,
    last_message_type VARCHAR(20) DEFAULT 'text',
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS blocked_member_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_text TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_type VARCHAR(20) DEFAULT 'text';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();

-- 4. CHAT ISHTIROKCHILARI JADVALI (chat_participants)
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    unread_count INT DEFAULT 0,
    last_read_message_id TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;
ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS last_read_message_id TEXT;

-- 5. XABARLAR JADVALI (messages)
CREATE TABLE IF NOT EXISTS public.messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    reply_to_id TEXT,
    message_type VARCHAR(20) DEFAULT 'text',
    content TEXT,
    media_url TEXT,
    media_size BIGINT,
    file_name TEXT,
    voice_duration INT,
    status VARCHAR(20) DEFAULT 'sent',
    is_edited BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    reactions TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. FOYDALANUVCHI QURILMALARI JADVALI (user_devices - FCM Push Tokens)
CREATE TABLE IF NOT EXISTS public.user_devices (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_name TEXT,
    platform TEXT, -- 'android' | 'ios' | 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

ALTER TABLE IF EXISTS public.user_devices DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey;

-- 7. STORYLAR JADVALI (stories)
CREATE TABLE IF NOT EXISTS public.stories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    media_url TEXT NOT NULL,
    caption TEXT,
    is_video BOOLEAN DEFAULT false,
    viewed_by_users TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. BLOKLANGAN FOYDALANUVCHILAR JADVALI (blocked_users)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id TEXT PRIMARY KEY,
    blocker_id TEXT NOT NULL,
    blocked_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- 9. INDEXLAR (Tezkor yuklash va qidiruv uchun)
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);

-- 10. AVTOMATIK SUHBAT YARATUVCHI DATABASE TRIGGER
CREATE OR REPLACE FUNCTION public.handle_new_message_conversation()
RETURNS TRIGGER AS $$
DECLARE
  v_preview TEXT;
BEGIN
  IF NEW.message_type = 'image' THEN v_preview := '📷 Photo';
  ELSIF NEW.message_type = 'video' THEN v_preview := '🎥 Video';
  ELSIF NEW.message_type = 'voice' THEN v_preview := '🎤 Voice message';
  ELSIF NEW.message_type = 'doc' THEN v_preview := '📄 Document';
  ELSE v_preview := NEW.content;
  END IF;

  -- 1. Suhbat mavjudligini ta'minlash yoki yangilash
  INSERT INTO public.chats (id, is_group, created_by, last_message_text, last_message_type, last_message_at)
  VALUES (NEW.chat_id, false, NEW.sender_id, v_preview, NEW.message_type, NEW.created_at)
  ON CONFLICT (id) DO UPDATE SET
    last_message_text = v_preview,
    last_message_type = NEW.message_type,
    last_message_at = NEW.created_at;

  -- 2. Yuboruvchini ishtirokchi sifatida qo'shish
  INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
  VALUES (NEW.chat_id, NEW.sender_id, 'member', 0)
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  -- 3. Qabul qiluvchida o'qilmagan xabarlar sonini oshirish
  UPDATE public.chat_participants
  SET unread_count = unread_count + 1
  WHERE chat_id = NEW.chat_id AND user_id != NEW.sender_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_new_message_conversation ON public.messages;
CREATE TRIGGER trg_new_message_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_conversation();

-- 11. REALTIME PUBLICATION SOZLAMALARI
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chats') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.chats REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- 12. ROW LEVEL SECURITY (RLS) XAVFSIZLIK SOZLAMALARI
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Eski siyosatlarni tozalash
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
DROP POLICY IF EXISTS "chats_select_policy" ON public.chats;
DROP POLICY IF EXISTS "chats_insert_policy" ON public.chats;
DROP POLICY IF EXISTS "chats_update_policy" ON public.chats;
DROP POLICY IF EXISTS "chat_participants_select_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_update_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;
DROP POLICY IF EXISTS "user_devices_select_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_insert_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_update_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_delete_policy" ON public.user_devices;
DROP POLICY IF EXISTS "stories_select_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_insert_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_delete_policy" ON public.stories;
DROP POLICY IF EXISTS "blocked_users_all_policy" ON public.blocked_users;

-- Yangi ruxsat siyosatlari
CREATE POLICY "profiles_select_policy" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_policy" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE USING (true);

CREATE POLICY "chats_select_policy" ON public.chats FOR SELECT USING (true);
CREATE POLICY "chats_insert_policy" ON public.chats FOR INSERT WITH CHECK (true);
CREATE POLICY "chats_update_policy" ON public.chats FOR UPDATE USING (true);

CREATE POLICY "chat_participants_select_policy" ON public.chat_participants FOR SELECT USING (true);
CREATE POLICY "chat_participants_insert_policy" ON public.chat_participants FOR INSERT WITH CHECK (true);
CREATE POLICY "chat_participants_update_policy" ON public.chat_participants FOR UPDATE USING (true);

CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (true);
CREATE POLICY "messages_insert_policy" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "messages_delete_policy" ON public.messages FOR DELETE USING (true);

CREATE POLICY "user_devices_select_policy" ON public.user_devices FOR SELECT USING (true);
CREATE POLICY "user_devices_insert_policy" ON public.user_devices FOR INSERT WITH CHECK (true);
CREATE POLICY "user_devices_update_policy" ON public.user_devices FOR UPDATE USING (true);
CREATE POLICY "user_devices_delete_policy" ON public.user_devices FOR DELETE USING (true);

CREATE POLICY "stories_select_policy" ON public.stories FOR SELECT USING (true);
CREATE POLICY "stories_insert_policy" ON public.stories FOR INSERT WITH CHECK (true);
CREATE POLICY "stories_delete_policy" ON public.stories FOR DELETE USING (true);

CREATE POLICY "blocked_users_all_policy" ON public.blocked_users FOR ALL USING (true);

-- 13. STORAGE BUCKETLARINI SOZLASH
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;

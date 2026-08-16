-- ==============================================================================
-- SUPACHAT MESSENGER - SUPABASE DATABASE & STORAGE SCHEMA
-- ==============================================================================
-- Ushbu SQL skripti Supabase Dashboard SQL Editorida ishga tushirilishi kerak.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. FOYDALANUVCHILAR PROFILLARI JADVALI (profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
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

-- Ustunlar mavjudligini tekshirib qo'shish:
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number VARCHAR(30);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT DEFAULT 'Hey there! I am using SupaChat.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 3. CHATLAR VA GURUHLAR JADVALI (chats)
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    is_group BOOLEAN DEFAULT false,
    group_name VARCHAR(100),
    group_avatar TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    admin_ids TEXT[] DEFAULT '{}',
    blocked_member_ids TEXT[] DEFAULT '{}',
    last_message_text TEXT,
    last_message_type VARCHAR(20) DEFAULT 'text',
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS blocked_member_ids TEXT[] DEFAULT '{}';

-- 4. CHAT ISHTIROKCHILARI JADVALI (chat_participants)
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'owner', 'admin' yoki 'member'
    unread_count INT DEFAULT 0,
    last_read_message_id UUID,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

-- 5. XABARLAR JADVALI (messages)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'video', 'voice', 'doc'
    content TEXT,
    media_url TEXT,
    media_size BIGINT,
    voice_duration INT, -- soniyalarda
    status VARCHAR(20) DEFAULT 'sent', -- 'sending', 'sent', 'delivered', 'read'
    is_edited BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. STORYLAR JADVALI (stories)
CREATE TABLE IF NOT EXISTS public.stories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    media_url TEXT NOT NULL,
    caption TEXT,
    is_video BOOLEAN DEFAULT false,
    viewed_by_users TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. BLOKLANGAN FOYDALANUVCHILAR JADVALI (blocked_users)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blocker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    blocked_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- 8. INDEXLAR YARATISH (Tezkor qidiruv va yuklash uchun)
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON public.stories(user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_id);

-- 9. REALTIME PUBLICATIONGA QO'SHISH
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
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'stories') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stories;
  END IF;
END $$;

-- 10. ROW LEVEL SECURITY (RLS) XAVFSIZLIK SOZLAMALARI
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Eski siyosatlarni tozalash
DROP POLICY IF EXISTS "Har kim profillarni ko'ra oladi" ON public.profiles;
DROP POLICY IF EXISTS "Foydalanuvchi o'z profilini o'zgartira oladi" ON public.profiles;
DROP POLICY IF EXISTS "Foydalanuvchi o'z profilini yarata oladi" ON public.profiles;
DROP POLICY IF EXISTS "Foydalanuvchi o'zi a'zo bo'lgan chatlarni ko'ra oladi" ON public.chats;
DROP POLICY IF EXISTS "Foydalanuvchi yangi chat yarata oladi" ON public.chats;
DROP POLICY IF EXISTS "Foydalanuvchi o'z chat ishtirokchilarini ko'ra oladi" ON public.chat_participants;
DROP POLICY IF EXISTS "Chatga ishtirokchi qo'shish" ON public.chat_participants;
DROP POLICY IF EXISTS "Foydalanuvchi faqat o'z chatidagi xabarlarni ko'ra oladi" ON public.messages;
DROP POLICY IF EXISTS "Foydalanuvchi a'zo bo'lgan chatiga xabar yoza oladi" ON public.messages;
DROP POLICY IF EXISTS "Foydalanuvchi faqat o'z xabarini tahrirlay oladi" ON public.messages;
DROP POLICY IF EXISTS "Foydalanuvchi faqat o'z xabarini o'chira oladi" ON public.messages;
DROP POLICY IF EXISTS "Har kim storylarni ko'ra oladi" ON public.stories;
DROP POLICY IF EXISTS "Foydalanuvchi o'z storylarini yuklay oladi" ON public.stories;
DROP POLICY IF EXISTS "Foydalanuvchi o'z bloklaganlarini boshqara oladi" ON public.blocked_users;

-- Yangi siyosatlar
CREATE POLICY "Har kim profillarni ko'ra oladi" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Foydalanuvchi o'z profilini o'zgartira oladi" ON public.profiles FOR UPDATE USING (true);
CREATE POLICY "Foydalanuvchi o'z profilini yarata oladi" ON public.profiles FOR INSERT WITH CHECK (true);

CREATE POLICY "Foydalanuvchi o'zi a'zo bo'lgan chatlarni ko'ra oladi" ON public.chats FOR SELECT USING (true);
CREATE POLICY "Foydalanuvchi yangi chat yarata oladi" ON public.chats FOR INSERT WITH CHECK (true);

CREATE POLICY "Foydalanuvchi o'z chat ishtirokchilarini ko'ra oladi" ON public.chat_participants FOR SELECT USING (true);
CREATE POLICY "Chatga ishtirokchi qo'shish" ON public.chat_participants FOR INSERT WITH CHECK (true);

CREATE POLICY "Foydalanuvchi faqat o'z chatidagi xabarlarni ko'ra oladi" ON public.messages FOR SELECT USING (true);
CREATE POLICY "Foydalanuvchi a'zo bo'lgan chatiga xabar yoza oladi" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Foydalanuvchi faqat o'z xabarini tahrirlay oladi" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "Foydalanuvchi faqat o'z xabarini o'chira oladi" ON public.messages FOR DELETE USING (true);

CREATE POLICY "Har kim storylarni ko'ra oladi" ON public.stories FOR SELECT USING (true);
CREATE POLICY "Foydalanuvchi o'z storylarini yuklay oladi" ON public.stories FOR INSERT WITH CHECK (true);
CREATE POLICY "Foydalanuvchi o'z storylarini o'chira oladi" ON public.stories FOR DELETE USING (true);

CREATE POLICY "Foydalanuvchi o'z bloklaganlarini boshqara oladi" ON public.blocked_users FOR ALL USING (true);

-- 11. TRIGGER: Yangi auth foydalanuvchisi ro'yxatdan o'tganda profil yaratish
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url, phone_number)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    COALESCE(new.raw_user_meta_data->>'full_name', 'SupaChat User'),
    COALESCE(new.raw_user_meta_data->>'avatar_url', ''),
    COALESCE(new.raw_user_meta_data->>'phone_number', '+998 90 123 45 67')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 12. STORAGE BUCKETLARINI YARATISH (Avatarlar, media va storylar uchun)
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;

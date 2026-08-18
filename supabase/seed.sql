-- ==============================================================================
-- SUPACHAT MESSENGER - DATABASE INITIALIZATION
-- ==============================================================================
-- Ushbu skript Supabase Dashboard SQL Editorida ishga tushirilsa,
-- jadvallar va ustunlar sozlamalarini to'g'rilaydi.

-- 0. CHEKLOVLARNI TO'G'RILASH (Foreign Key va Ustunlarni sozlash)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT DEFAULT 'Hey there! I am using SupaChat.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

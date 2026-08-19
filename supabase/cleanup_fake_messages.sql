-- ==============================================================================
-- SUPACHAT: FAKE MESSAGES & ORPHAN CHATS CLEANUP
-- ==============================================================================
-- Logdan ko'ringan fake xabar va chat ID'larni o'chiradi:
--   Messages: e1f2a3b4-c5d6-4e5f-8a9b-0c1d2e3f4a5b
--             b1c2d3e4-f5a6-4b5c-8d7e-0f1a2b3c4d5e
--   Chats:    a1b2c3d4-e5f6-4a5b-8c7d-9e0f1a2b3c4d
--             d3f0e553-dcda-5ab3-a980-84986e63f760  (eski chatId mismatch)
-- Shuningdek chat_participants'da UUID bo'lmagan (username) yozuvlarni o'chiradi
-- ==============================================================================

BEGIN;

-- 1. Aniq fake xabarlarni o'chirish (logda ko'ringan)
DELETE FROM public.messages
WHERE id IN (
    'e1f2a3b4-c5d6-4e5f-8a9b-0c1d2e3f4a5b',
    'b1c2d3e4-f5a6-4b5c-8d7e-0f1a2b3c4d5e'
);

-- 2. Fake / orphan chat'lardan xabarlarni tozalash
DELETE FROM public.messages
WHERE chat_id IN (
    'a1b2c3d4-e5f6-4a5b-8c7d-9e0f1a2b3c4d',
    'd3f0e553-dcda-5ab3-a980-84986e63f760'
);

-- 3. Fake chat_participants yozuvlarini tozalash
DELETE FROM public.chat_participants
WHERE chat_id IN (
    'a1b2c3d4-e5f6-4a5b-8c7d-9e0f1a2b3c4d',
    'd3f0e553-dcda-5ab3-a980-84986e63f760'
);

-- 4. Fake chat'larni o'chirish
DELETE FROM public.chats
WHERE id IN (
    'a1b2c3d4-e5f6-4a5b-8c7d-9e0f1a2b3c4d',
    'd3f0e553-dcda-5ab3-a980-84986e63f760'
);

-- 5. chat_participants'da UUID bo'lmagan user_id yozuvlarini o'chirish
--    (masalan: "salim", "user-anvarjon" kabi username yozuvlar 22P02 xatosiga sabab bo'ladi)
--    user_id uuid tipida bo'lgani uchun ::text cast qilinadi
DELETE FROM public.chat_participants
WHERE user_id::text !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

-- 6. Ishtirokchisi bo'lmagan orphan chat'larni o'chirish
DELETE FROM public.messages
WHERE chat_id NOT IN (SELECT DISTINCT chat_id FROM public.chat_participants);

DELETE FROM public.chats
WHERE id NOT IN (SELECT DISTINCT chat_id FROM public.chat_participants);

COMMIT;

-- 7. Natijani tekshirish
SELECT
    (SELECT COUNT(*) FROM public.messages)         AS messages_count,
    (SELECT COUNT(*) FROM public.chats)            AS chats_count,
    (SELECT COUNT(*) FROM public.chat_participants) AS participants_count,
    (SELECT COUNT(*) FROM public.profiles)         AS profiles_count;

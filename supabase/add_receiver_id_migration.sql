-- ==============================================================================
-- SUPACHAT: receiver_id MIGRATION
-- ==============================================================================
-- MUHIM: Ushbu faylni Supabase SQL Editor'da 2 BOSQICHDA ishga tushiring:
--   BOSQICH 1: 11-12 qatorni (ALTER TABLE) tanlang va Run bosing
--   BOSQICH 2: 18-58 qatorni (CREATE OR REPLACE FUNCTION) tanlang va Run bosing
-- ==============================================================================

-- ==================== BOSQICH 1 ====================
-- messages jadvaliga receiver_id ustunini qo'shish
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS receiver_id TEXT;

CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);
-- ==================== END BOSQICH 1 ================


-- ==================== BOSQICH 2 ====================
-- Trigger funksiyasini yangilash (receiver ham participant bo'ladi)
CREATE OR REPLACE FUNCTION public.handle_new_message_conversation()
RETURNS TRIGGER AS $$
DECLARE
  v_preview TEXT;
BEGIN
  IF NEW.message_type = 'image' THEN v_preview := 'Photo';
  ELSIF NEW.message_type = 'video' THEN v_preview := 'Video';
  ELSIF NEW.message_type = 'voice' THEN v_preview := 'Voice message';
  ELSIF NEW.message_type = 'doc' THEN v_preview := 'Document';
  ELSE v_preview := NEW.content;
  END IF;

  INSERT INTO public.chats (id, is_group, created_by, last_message_text, last_message_type, last_message_sender_id, last_message_at)
  VALUES (NEW.chat_id, false, NEW.sender_id, v_preview, NEW.message_type, NEW.sender_id, NEW.created_at)
  ON CONFLICT (id) DO UPDATE SET
    last_message_text      = v_preview,
    last_message_type      = NEW.message_type,
    last_message_sender_id = NEW.sender_id,
    last_message_at        = NEW.created_at;

  INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
  VALUES (NEW.chat_id, NEW.sender_id, 'member', 0)
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  IF NEW.receiver_id IS NOT NULL THEN
    INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
    VALUES (NEW.chat_id, NEW.receiver_id, 'member', 1)
    ON CONFLICT (chat_id, user_id) DO UPDATE
      SET unread_count = public.chat_participants.unread_count + 1;
  END IF;

  UPDATE public.chat_participants
  SET unread_count = unread_count + 1
  WHERE chat_id = NEW.chat_id
    AND user_id != NEW.sender_id
    AND (NEW.receiver_id IS NULL OR user_id != NEW.receiver_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- ==================== END BOSQICH 2 ================

// ==============================================================================
// SUPACHAT MESSENGER - SUPABASE EDGE FUNCTION: PUSH NOTIFICATIONS (FCM)
// ==============================================================================
// Triggered via Supabase Database Webhook on INSERT into "public.messages" table.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: {
    id: string;
    chat_id: string;
    sender_id: string;
    content: string;
    message_type: string;
    created_at: string;
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: "Missing Supabase Environment Variables" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body: WebhookPayload = await req.json();

    if (body.type !== "INSERT" || body.table !== "messages" || !body.record) {
      return new Response(JSON.stringify({ message: "Not a message insert event" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { id: messageId, chat_id: chatId, sender_id: senderId, content, message_type: msgType } = body.record;

    // 1. Fetch Sender Profile
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("full_name, username, avatar_url")
      .eq("id", senderId)
      .maybeSingle();

    const senderName = senderProfile?.full_name || "SupaChat User";
    const senderUsername = senderProfile?.username || senderId;

    // 2. Format Message Preview Text
    let previewText = content;
    if (msgType === "image") previewText = "📷 Photo";
    else if (msgType === "video") previewText = "🎥 Video";
    else if (msgType === "voice") previewText = "🎤 Voice message";
    else if (msgType === "doc") previewText = "📄 Document";

    const notificationBody = `${senderName} (@${senderUsername}): ${previewText}`;

    // 3. Find Recipient(s) for this Chat
    const { data: participants } = await supabase
      .from("chat_participants")
      .select("user_id")
      .eq("chat_id", chatId)
      .neq("user_id", senderId);

    const recipientIds: string[] = (participants || []).map((p) => p.user_id);

    // If chat_participants is not populated (e.g. direct chat first message), resolve recipient
    if (recipientIds.length === 0) {
      // Find all profiles except sender if needed, or query direct chat pairing
      const { data: directProfiles } = await supabase
        .from("profiles")
        .select("id, fcm_token")
        .neq("id", senderId);

      if (directProfiles) {
        for (const p of directProfiles) {
          if (p.fcm_token) {
            recipientIds.push(p.id);
          }
        }
      }
    }

    if (recipientIds.length === 0) {
      return new Response(JSON.stringify({ message: "No recipients found" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Retrieve FCM Tokens from profiles / user_devices
    const { data: recipientProfiles } = await supabase
      .from("profiles")
      .select("id, fcm_token")
      .in("id", recipientIds);

    const fcmTokens: string[] = [];
    const tokenToUserMap = new Map<string, string>();

    for (const p of recipientProfiles || []) {
      if (p.fcm_token && p.fcm_token.trim().length > 10) {
        fcmTokens.push(p.fcm_token.trim());
        tokenToUserMap.set(p.fcm_token.trim(), p.id);
      }
    }

    if (fcmTokens.length === 0) {
      return new Response(JSON.stringify({ message: "No active FCM tokens for recipients" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 5. Send Push Notification via Firebase Cloud Messaging API
    let sentCount = 0;
    const expiredTokens: string[] = [];

    for (const token of fcmTokens) {
      try {
        const fcmPayload = {
          to: token,
          priority: "high",
          notification: {
            title: "New message",
            body: notificationBody,
            sound: "default",
            badge: "1",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          data: {
            chat_id: chatId,
            sender_id: senderId,
            sender_name: senderName,
            sender_username: senderUsername,
            message_id: messageId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${fcmServerKey}`,
          },
          body: JSON.stringify(fcmPayload),
        });

        const fcmResult = await fcmResponse.json();

        if (fcmResult.success === 1) {
          sentCount++;
        } else if (
          fcmResult.results &&
          fcmResult.results[0]?.error &&
          (fcmResult.results[0].error === "NotRegistered" ||
            fcmResult.results[0].error === "InvalidRegistration")
        ) {
          // Token has expired or app was uninstalled
          expiredTokens.push(token);
        }
      } catch (err) {
        console.error(`Error sending push to token ${token}:`, err);
      }
    }

    // 6. Clean up expired / invalid FCM tokens from database
    if (expiredTokens.length > 0) {
      for (const expiredToken of expiredTokens) {
        const userId = tokenToUserMap.get(expiredToken);
        if (userId) {
          await supabase
            .from("profiles")
            .update({ fcm_token: null })
            .eq("id", userId);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: sentCount,
        recipients: fcmTokens.length,
        cleanedExpired: expiredTokens.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

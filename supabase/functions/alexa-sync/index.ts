// Forwards the app's upcoming reminders to the linked Alexa skill through the
// Skill Messaging API; the skill then creates/deletes the Echo reminders.
//
// Secrets: ALEXA_CLIENT_ID, ALEXA_CLIENT_SECRET (skill console -> Build ->
// Permissions -> Alexa Skill Messaging). Optional ALEXA_API_HOST for
// Europe (https://api.eu.amazonalexa.com) or Far East (https://api.fe.amazon.com).
// Self-contained so it can be pasted into the Supabase dashboard editor.
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

/** Service-role client: bypasses row-level security, server side only. */
export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** The signed-in (anonymous) app user making the request, or null. */
export async function appUser(req: Request): Promise<User | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user;
}


let cachedToken: { value: string; expires: number } | null = null;

async function skillToken(): Promise<string> {
  if (cachedToken && cachedToken.expires > Date.now() + 60_000) return cachedToken.value;
  const res = await fetch("https://api.amazon.com/auth/o2/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: Deno.env.get("ALEXA_CLIENT_ID")!,
      client_secret: Deno.env.get("ALEXA_CLIENT_SECRET")!,
      scope: "alexa:skill_messaging",
    }),
  });
  if (!res.ok) throw new Error(`token request failed: ${res.status} ${await res.text()}`);
  const body = await res.json();
  cachedToken = { value: body.access_token, expires: Date.now() + body.expires_in * 1000 };
  return cachedToken.value;
}

Deno.serve(async (req) => {
  const user = await appUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  const { data: link } = await admin
    .from("alexa_links")
    .select("alexa_user_id")
    .eq("app_user", user.id)
    .maybeSingle();
  if (!link) return json({ linked: false });

  // [{id, title, at: "YYYY-MM-DDTHH:mm:ss" (phone's local time), everyMin, count}]
  const { tasks } = await req.json();
  const host = Deno.env.get("ALEXA_API_HOST") ?? "https://api.amazonalexa.com";
  const res = await fetch(
    `${host}/v1/skillmessages/users/${encodeURIComponent(link.alexa_user_id)}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${await skillToken()}`,
      },
      // The skill must act within the hour; older states are superseded anyway.
      body: JSON.stringify({ data: { tasks }, expiresAfterSeconds: 3600 }),
    },
  );
  if (res.status !== 202) {
    return json({ linked: true, error: `skill message failed: ${res.status} ${await res.text()}` }, 502);
  }
  return json({ linked: true, sent: tasks.length });
});

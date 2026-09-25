// Used by the approval web page (docs/approve/index.html), not the app.
//   GET  ?id=...&t=...                         -> title, approver, status, photo link
//   POST {id, t, decision: approve|reject, note} -> records the decision
// Deploy with JWT verification OFF: the per-request secret token in the link
// is the access check. Self-contained for the Supabase dashboard editor.
import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...cors },
  });
}

/** Loads the request if the token matches; null otherwise. */
async function load(id: string | null, token: string | null) {
  if (!id || !token) return null;
  const { data } = await admin.from("photo_approvals").select("*").eq("id", id).maybeSingle();
  if (!data || data.token.length !== token.length) return null;
  // Constant-time compare so the token can't be guessed byte by byte.
  let diff = 0;
  for (let i = 0; i < token.length; i++) diff |= data.token.charCodeAt(i) ^ token.charCodeAt(i);
  return diff === 0 ? data : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  if (req.method === "GET") {
    const params = new URL(req.url).searchParams;
    const row = await load(params.get("id"), params.get("t"));
    if (!row) return json({ error: "This link is invalid or has expired." }, 404);
    let photoUrl: string | null = null;
    if (row.photo_path) {
      const signed = await admin.storage.from("proof-photos").createSignedUrl(row.photo_path, 3600);
      photoUrl = signed.data?.signedUrl ?? null;
    }
    return json({
      title: row.task_title,
      approverName: row.approver_name,
      status: row.status,
      note: row.note,
      createdAt: row.created_at,
      photoUrl,
    });
  }

  if (req.method === "POST") {
    const { id, t, decision, note } = await req.json();
    const row = await load(id, t);
    if (!row) return json({ error: "This link is invalid or has expired." }, 404);
    if (row.status !== "pending") return json({ status: row.status });
    if (decision !== "approve" && decision !== "reject") return json({ error: "bad decision" }, 400);

    const status = decision === "approve" ? "approved" : "rejected";
    await admin.from("photo_approvals").update({
      status,
      note: note ? String(note).slice(0, 200) : null,
      decided_at: new Date().toISOString(),
      photo_path: null,
    }).eq("id", id);
    // Privacy: the photo isn't needed once it's been judged.
    if (row.photo_path) await admin.storage.from("proof-photos").remove([row.photo_path]);
    return json({ status });
  }

  return json({ error: "method not allowed" }, 405);
});

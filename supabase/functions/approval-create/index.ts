// The app uploads a "task done" photo and gets back a link for the approver.
// Optional secret APPROVE_PAGE_URL (default: the GitHub Pages page below).
// Self-contained so it can be pasted into the Supabase dashboard editor.
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

/** Server key: SUPABASE_SECRET_KEYS on new projects, service_role on older ones. */
function serverKey(): string {
  const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  return keys.default ?? Object.values(keys)[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
}
/** Server-side client: bypasses row-level security. */
const admin = createClient(Deno.env.get("SUPABASE_URL")!, serverKey());

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function appUser(req: Request): Promise<User | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user;
}

function randomHex(bytes: number): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(bytes)))
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  const user = await appUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  const { title, approverName, photo } = await req.json();
  if (!title || !approverName || !photo) return json({ error: "missing fields" }, 400);
  const bytes = Uint8Array.from(atob(photo), (c) => c.charCodeAt(0));
  if (bytes.length > 4_000_000) return json({ error: "photo too large" }, 413);

  const id = crypto.randomUUID();
  const token = randomHex(24);
  const path = `${user.id}/${id}.jpg`;

  const upload = await admin.storage.from("proof-photos")
    .upload(path, bytes, { contentType: "image/jpeg" });
  if (upload.error) return json({ error: upload.error.message }, 500);

  const { error } = await admin.from("photo_approvals").insert({
    id,
    token,
    app_user: user.id,
    task_title: String(title).slice(0, 100),
    approver_name: String(approverName).slice(0, 40),
    photo_path: path,
  });
  if (error) return json({ error: error.message }, 500);

  const page = Deno.env.get("APPROVE_PAGE_URL") ?? "https://dracon420.github.io/TNWR/approve/";
  const api = Deno.env.get("SUPABASE_URL")!;
  const url = `${page}?api=${encodeURIComponent(api)}&id=${id}&t=${token}`;
  return json({ id, url });
});

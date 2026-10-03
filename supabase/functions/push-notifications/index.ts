const corsHeaders = {
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info, x-push-dispatch-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Origin": "*",
};

type JsonRecord = Record<string, unknown>;
type ServiceAccount = {
  client_email: string;
  private_key: string;
};
type ReminderJob = {
  id: string;
  task_id: string;
  user_id: string;
  title: string;
};
type FirebaseNotice = {
  title: string;
  body: string;
  data: Record<string, string>;
};

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiresAt = 0;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function serviceHeaders(): HeadersInit {
  const key = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

async function authenticateUser(request: Request): Promise<string | null> {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return null;

  const response = await fetch(`${requiredEnv("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      apikey: requiredEnv("SUPABASE_ANON_KEY"),
      Authorization: authorization,
    },
  });
  if (!response.ok) return null;

  const user = await response.json() as { id?: string };
  return typeof user.id === "string" ? user.id : null;
}

async function registerDevice(userId: string, token: string): Promise<Response> {
  if (token.length < 20 || token.length > 4096) {
    return jsonResponse({ error: "The Firebase device token is invalid." }, 400);
  }

  const url = new URL(
    `${requiredEnv("SUPABASE_URL")}/rest/v1/push_device_tokens`,
  );
  url.searchParams.set("on_conflict", "token");
  const response = await fetch(url, {
    method: "POST",
    headers: {
      ...serviceHeaders(),
      Prefer: "resolution=merge-duplicates,return=minimal",
    },
    body: JSON.stringify({ token, user_id: userId, updated_at: new Date().toISOString() }),
  });
  if (!response.ok) {
    console.error("Could not store a push device token:", response.status);
    return jsonResponse({ error: "Could not register push notifications." }, 502);
  }
  return jsonResponse({ registered: true });
}

async function unregisterDevice(userId: string, token: string): Promise<Response> {
  const url = new URL(
    `${requiredEnv("SUPABASE_URL")}/rest/v1/push_device_tokens`,
  );
  url.searchParams.set("user_id", `eq.${userId}`);
  url.searchParams.set("token", `eq.${token}`);
  const response = await fetch(url, {
    method: "DELETE",
    headers: serviceHeaders(),
  });
  if (!response.ok) {
    console.error("Could not remove a push device token:", response.status);
    return jsonResponse({ error: "Could not unregister this device." }, 502);
  }
  return jsonResponse({ registered: false });
}

function encodeBase64Url(value: string | Uint8Array): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

async function createGoogleAccessToken(): Promise<string> {
  if (cachedAccessToken && Date.now() < cachedAccessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }

  const serviceAccount = JSON.parse(
    requiredEnv("FCM_SERVICE_ACCOUNT"),
  ) as ServiceAccount;
  const now = Math.floor(Date.now() / 1000);
  const unsignedToken = [
    encodeBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" })),
    encodeBase64Url(JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })),
  ].join(".");

  const privateKeyBody = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const privateKeyBytes = Uint8Array.from(atob(privateKeyBody), (char) =>
    char.charCodeAt(0)
  );
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      new TextEncoder().encode(unsignedToken),
    ),
  );
  const assertion = `${unsignedToken}.${encodeBase64Url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    console.error("Firebase OAuth token request failed:", response.status);
    throw new Error("Firebase OAuth authentication failed.");
  }

  const result = await response.json() as {
    access_token?: string;
    expires_in?: number;
  };
  if (!result.access_token) throw new Error("Firebase returned no access token.");
  cachedAccessToken = result.access_token;
  cachedAccessTokenExpiresAt =
    Date.now() + (result.expires_in ?? 3600) * 1000;
  return cachedAccessToken;
}

async function sendFirebaseMessage(
  token: string,
  notice: FirebaseNotice,
): Promise<{ delivered: boolean; invalidToken: boolean }> {
  const projectId = requiredEnv("FCM_PROJECT_ID");
  const accessToken = await createGoogleAccessToken();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: notice.title, body: notice.body },
          data: notice.data,
          android: {
            priority: "HIGH",
            notification: { channel_id: "task_reminders" },
          },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    },
  );

  if (response.ok) return { delivered: true, invalidToken: false };
  const errorBody = await response.text();
  const invalidToken =
    response.status === 404 ||
    (response.status === 400 && errorBody.includes("UNREGISTERED"));
  console.error("Firebase message delivery failed:", response.status);
  return { delivered: false, invalidToken };
}

async function sendToUserDevices(
  userId: string,
  notice: FirebaseNotice,
): Promise<{ registered: number; delivered: number }> {
  const tokensUrl = new URL(
    `${requiredEnv("SUPABASE_URL")}/rest/v1/push_device_tokens`,
  );
  tokensUrl.searchParams.set("select", "token");
  tokensUrl.searchParams.set("user_id", `eq.${userId}`);
  const tokensResponse = await fetch(tokensUrl, { headers: serviceHeaders() });
  if (!tokensResponse.ok) {
    console.error("Could not load a user's push devices:", tokensResponse.status);
    throw new Error("Could not load registered push devices.");
  }

  const tokens = await tokensResponse.json() as { token: string }[];
  let delivered = 0;
  for (const { token } of tokens) {
    const result = await sendFirebaseMessage(token, notice);
    if (result.delivered) delivered++;
    if (result.invalidToken) {
      const deleteUrl = new URL(
        `${requiredEnv("SUPABASE_URL")}/rest/v1/push_device_tokens`,
      );
      deleteUrl.searchParams.set("token", `eq.${token}`);
      const deletion = await fetch(deleteUrl, {
        method: "DELETE",
        headers: serviceHeaders(),
      });
      if (!deletion.ok) {
        console.error("Could not remove an invalid push token:", deletion.status);
      }
    }
  }
  return { registered: tokens.length, delivered };
}

async function notifyScheduleGenerated(
  userId: string,
  body: JsonRecord,
): Promise<Response> {
  const date = body.schedule_date;
  const taskCount = body.task_count;
  if (
    typeof date !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    typeof taskCount !== "number" ||
    !Number.isInteger(taskCount) ||
    taskCount < 0 ||
    taskCount > 500
  ) {
    return jsonResponse({ error: "The schedule notification details are invalid." }, 400);
  }

  const result = await sendToUserDevices(userId, {
    title: "Schedule ready",
    body: `Your schedule for ${date} is ready with ${taskCount} task${taskCount === 1 ? "" : "s"}.`,
    data: { event: "schedule_generated", schedule_date: date },
  });
  return jsonResponse({
    delivered: result.delivered > 0,
    delivered_devices: result.delivered,
    registered_devices: result.registered,
    reason: result.registered === 0 ? "no_registered_devices" : null,
  });
}

async function updateJob(
  jobId: string,
  status: "sent" | "failed",
  error: string | null,
): Promise<void> {
  const url = new URL(
    `${requiredEnv("SUPABASE_URL")}/rest/v1/push_notification_jobs`,
  );
  url.searchParams.set("id", `eq.${jobId}`);
  const response = await fetch(url, {
    method: "PATCH",
    headers: { ...serviceHeaders(), Prefer: "return=minimal" },
    body: JSON.stringify({
      status,
      processing_started_at: null,
      dispatched_at: new Date().toISOString(),
      last_error: error,
    }),
  });
  if (!response.ok) {
    console.error("Could not update a push notification job:", response.status);
    throw new Error("Could not record push notification delivery status.");
  }
}

async function dispatchDueReminders(): Promise<Response> {
  const jobsResponse = await fetch(
    `${requiredEnv("SUPABASE_URL")}/rest/v1/rpc/claim_due_push_notification_jobs`,
    {
      method: "POST",
      headers: serviceHeaders(),
      body: JSON.stringify({ batch_size: 100 }),
    },
  );
  if (!jobsResponse.ok) {
    console.error("Could not load due push reminder jobs:", jobsResponse.status);
    return jsonResponse({ error: "Could not load reminder jobs." }, 502);
  }
  const jobs = await jobsResponse.json() as ReminderJob[];
  let deliveredJobs = 0;

  for (const job of jobs) {
    try {
      const result = await sendToUserDevices(job.user_id, {
        title: "Task reminder",
        body: job.title,
        data: { task_id: job.task_id, event: "task_reminder" },
      });
      const delivered = result.delivered > 0;
      await updateJob(
        job.id,
        delivered ? "sent" : "failed",
        delivered
          ? null
          : result.registered === 0
            ? "No registered push devices."
            : "Firebase did not accept the notification.",
      );
      if (delivered) deliveredJobs++;
    } catch (error) {
      console.error("Could not dispatch a task reminder:", error);
      await updateJob(job.id, "failed", "Could not dispatch the notification.");
    }
  }

  return jsonResponse({ processed: jobs.length, delivered: deliveredJobs });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const body = await request.json() as JsonRecord;
    if (body.action === "dispatch") {
      const expectedSecret = requiredEnv("PUSH_DISPATCH_SECRET");
      if (request.headers.get("X-Push-Dispatch-Secret") !== expectedSecret) {
        return jsonResponse({ error: "Unauthorized." }, 401);
      }
      return await dispatchDueReminders();
    }

    const userId = await authenticateUser(request);
    if (!userId) return jsonResponse({ error: "Unauthorized." }, 401);
    if (body.action === "schedule_generated") {
      return await notifyScheduleGenerated(userId, body);
    }
    if (typeof body.token !== "string") {
      return jsonResponse({ error: "A Firebase device token is required." }, 400);
    }

    if (body.action === "register") {
      return await registerDevice(userId, body.token);
    }
    if (body.action === "unregister") {
      return await unregisterDevice(userId, body.token);
    }
    return jsonResponse({ error: "Unsupported notification action." }, 400);
  } catch (error) {
    console.error("Push notification request failed:", error);
    return jsonResponse({ error: "Push notification request failed." }, 500);
  }
});

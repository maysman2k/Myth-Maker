const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const accessToken = Deno.env.get("INSTAGRAM_ACCESS_TOKEN");
    const userID = Deno.env.get("INSTAGRAM_USER_ID") ?? "me";
    const graphVersion = Deno.env.get("INSTAGRAM_GRAPH_VERSION") ?? "v23.0";

    if (!accessToken) {
      return json({ error: "INSTAGRAM_ACCESS_TOKEN is not configured." }, 500);
    }

    const requestURL = new URL(req.url);
    const limit = Math.min(Number(requestURL.searchParams.get("limit") ?? "5") || 5, 10);
    const fields = "id,caption,media_type,media_url,thumbnail_url,permalink,timestamp";
    const instagramURL = new URL(`https://graph.facebook.com/${graphVersion}/${userID}/media`);
    instagramURL.searchParams.set("fields", fields);
    instagramURL.searchParams.set("limit", String(limit));
    instagramURL.searchParams.set("access_token", accessToken);

    const response = await fetch(instagramURL);
    const payload = await response.json();

    if (!response.ok) {
      return json({ error: payload?.error?.message ?? "Instagram request failed." }, response.status);
    }

    return json({
      posts: Array.isArray(payload.data) ? payload.data.slice(0, limit) : [],
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown Instagram feed error." }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=300",
    },
  });
}

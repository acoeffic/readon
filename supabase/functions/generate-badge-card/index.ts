import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";
import React from "https://esm.sh/react@18.2.0";
import { ImageResponse } from "https://deno.land/x/og_edge@0.0.6/mod.ts";

// ── Environment ─────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
  throw new Error(
    "Missing SUPABASE_URL, SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY"
  );
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Helpers ─────────────────────────────────────────────────────────

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function hashCode(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash + str.charCodeAt(i)) | 0;
  }
  return hash;
}

function seededRandom(seed: number): () => number {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) & 0xffffffff;
    return (s >>> 0) / 0xffffffff;
  };
}

interface Star {
  x: number;
  y: number;
  r: number;
  opacity: number;
}

function generateStars(badgeId: string, count: number): Star[] {
  const rng = seededRandom(hashCode(badgeId));
  return Array.from({ length: count }, () => ({
    x: rng() * 420,
    y: rng() * 600,
    r: 0.5 + rng() * 1.2,
    opacity: 0.15 + rng() * 0.35,
  }));
}

function formatDate(): string {
  const now = new Date();
  const months = [
    "jan.",
    "fév.",
    "mar.",
    "avr.",
    "mai",
    "juin",
    "juil.",
    "août",
    "sep.",
    "oct.",
    "nov.",
    "déc.",
  ];
  return `${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`;
}

function formatNumber(n: number): string {
  if (n >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
  return n.toString();
}

function formatHours(minutes: number): string {
  const h = Math.floor(minutes / 60);
  if (h === 0) return `${Math.round(minutes)}min`;
  return `${h}h`;
}

// Category display labels
const CATEGORY_LABELS: Record<string, string> = {
  books_completed: "Livres",
  reading_time: "Temps de lecture",
  streak: "Régularité",
  goals: "Objectifs",
  social: "Social",
  genres: "Genres",
  engagement: "Engagement",
  animated: "Spécial",
  secret: "Secret",
  style: "Style de lecture",
  monthly: "Mensuel",
  yearly: "Annuel",
  anniversary: "Anniversaire",
  annual_books: "Livres annuels",
  occasion: "Occasion",
};

// ── Font loading ────────────────────────────────────────────────────

async function loadGoogleFont(
  family: string,
  weight: number
): Promise<ArrayBuffer> {
  const cssUrl = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(
    family
  )}:wght@${weight}&display=swap`;
  const cssRes = await fetch(cssUrl, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    },
  });
  const css = await cssRes.text();
  const match = css.match(/src: url\((.+?)\) format\('(woff2|truetype)'\)/);
  if (!match) throw new Error(`Font not found: ${family} ${weight}`);
  const fontRes = await fetch(match[1]);
  return fontRes.arrayBuffer();
}

// Cache fonts at module level (reused across warm invocations)
const cormorantBold = loadGoogleFont("Cormorant Garamond", 700);
const cormorantSemiBold = loadGoogleFont("Cormorant Garamond", 600);
const dmSansLight = loadGoogleFont("DM Sans", 300);
const dmSansRegular = loadGoogleFont("DM Sans", 400);
const dmSansMedium = loadGoogleFont("DM Sans", 500);

// ── Card component ──────────────────────────────────────────────────

interface BadgeData {
  name: string;
  description: string;
  icon: string;
  category: string;
  color: string;
}

interface CardProps {
  badge: BadgeData;
  booksCount: number;
  totalPages: number;
  totalHours: string;
  stars: Star[];
}

function BadgeCard({ badge, booksCount, totalPages, totalHours, stars }: CardProps) {
  const categoryLabel = CATEGORY_LABELS[badge.category] || badge.category;

  return React.createElement(
    "div",
    {
      style: {
        width: 420,
        height: 600,
        display: "flex",
        flexDirection: "column" as const,
        alignItems: "center",
        justifyContent: "center",
        background: "#0F172A",
        position: "relative" as const,
        overflow: "hidden",
        fontFamily: "DM Sans",
      },
    },
    // Stars background
    ...stars.map((star, i) =>
      React.createElement("div", {
        key: `s${i}`,
        style: {
          position: "absolute" as const,
          left: star.x,
          top: star.y,
          width: star.r * 2,
          height: star.r * 2,
          borderRadius: "50%",
          background: `rgba(255, 255, 255, ${star.opacity})`,
        },
      })
    ),

    // Glow behind badge
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        width: 360,
        height: 360,
        borderRadius: "50%",
        background: "radial-gradient(circle, rgba(107,152,141,0.18) 0%, transparent 70%)",
        top: "50%",
        left: "50%",
        transform: "translate(-50%, -56%)",
      },
    }),

    // Top green bar
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        top: 0,
        left: 0,
        right: 0,
        height: 3,
        background: "linear-gradient(90deg, transparent, #6B988D, transparent)",
        opacity: 0.8,
      },
    }),

    // Corner decorations
    // Top-left
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        top: 16,
        left: 16,
        width: 20,
        height: 20,
        borderTop: "1px solid #6B988D",
        borderLeft: "1px solid #6B988D",
        opacity: 0.3,
      },
    }),
    // Top-right
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        top: 16,
        right: 16,
        width: 20,
        height: 20,
        borderTop: "1px solid #6B988D",
        borderRight: "1px solid #6B988D",
        opacity: 0.3,
      },
    }),
    // Bottom-left
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        bottom: 16,
        left: 16,
        width: 20,
        height: 20,
        borderBottom: "1px solid #6B988D",
        borderLeft: "1px solid #6B988D",
        opacity: 0.3,
      },
    }),
    // Bottom-right
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        bottom: 16,
        right: 16,
        width: 20,
        height: 20,
        borderBottom: "1px solid #6B988D",
        borderRight: "1px solid #6B988D",
        opacity: 0.3,
      },
    }),

    // Logo area
    React.createElement(
      "div",
      {
        style: {
          position: "absolute" as const,
          top: 28,
          left: 0,
          right: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
        },
      },
      // Book icon SVG
      React.createElement(
        "svg",
        { width: 18, height: 22, viewBox: "0 0 24 30", fill: "none" },
        React.createElement("rect", {
          x: 1,
          y: 1,
          width: 22,
          height: 28,
          rx: 4,
          fill: "#6B988D",
        }),
        React.createElement("path", {
          d: "M1 22L12 17L23 22",
          fill: "#4a7a70",
        }),
        React.createElement("path", {
          d: "M8 29L12 25L16 29",
          fill: "#6B988D",
          stroke: "#6B988D",
          strokeWidth: 0.5,
        })
      ),
      React.createElement(
        "span",
        {
          style: {
            fontFamily: "Cormorant Garamond",
            fontSize: 18,
            fontWeight: 600,
            color: "#6B988D",
            letterSpacing: 2,
            textTransform: "uppercase" as const,
          },
        },
        "LexDay"
      )
    ),

    // Badge emoji in styled circle
    React.createElement(
      "div",
      {
        style: {
          width: 220,
          height: 220,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          marginBottom: 8,
          marginTop: -20,
        },
      },
      React.createElement(
        "div",
        {
          style: {
            width: 160,
            height: 160,
            borderRadius: "50%",
            background: `${badge.color}25`,
            border: `3px solid ${badge.color}60`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 80,
            boxShadow: `0 0 60px ${badge.color}30, 0 8px 32px rgba(0,0,0,0.6)`,
          },
        },
        badge.icon
      )
    ),

    // Content area
    React.createElement(
      "div",
      {
        style: {
          display: "flex",
          flexDirection: "column" as const,
          alignItems: "center",
          padding: "0 40px",
          textAlign: "center" as const,
        },
      },
      // "Badge débloqué" label
      React.createElement(
        "div",
        {
          style: {
            fontFamily: "DM Sans",
            fontSize: 10,
            fontWeight: 500,
            letterSpacing: 3,
            textTransform: "uppercase" as const,
            color: "#6B988D",
            marginBottom: 12,
            opacity: 0.9,
          },
        },
        "✦ Badge débloqué ✦"
      ),

      // Badge name
      React.createElement(
        "div",
        {
          style: {
            fontFamily: "Cormorant Garamond",
            fontSize: 36,
            fontWeight: 700,
            color: "#F5F1EB",
            lineHeight: 1.1,
            marginBottom: 6,
            letterSpacing: 0.5,
          },
        },
        badge.name
      ),

      // Category
      React.createElement(
        "div",
        {
          style: {
            fontFamily: "Cormorant Garamond",
            fontSize: 16,
            fontStyle: "italic" as const,
            color: "#94A3B8",
            letterSpacing: 1,
            marginBottom: 20,
          },
        },
        categoryLabel
      ),

      // Separator
      React.createElement("div", {
        style: {
          width: 40,
          height: 1,
          background: "linear-gradient(90deg, transparent, #6B988D, transparent)",
          marginBottom: 20,
        },
      }),

      // Description
      React.createElement(
        "div",
        {
          style: {
            fontFamily: "DM Sans",
            fontSize: 13,
            fontWeight: 300,
            color: "#94A3B8",
            lineHeight: 1.7,
          },
        },
        badge.description
      ),

      // Stats row
      React.createElement(
        "div",
        {
          style: {
            display: "flex",
            gap: 24,
            justifyContent: "center",
            marginTop: 22,
            paddingTop: 20,
            borderTop: "1px solid rgba(255,255,255,0.06)",
          },
        },
        // Books stat
        React.createElement(
          "div",
          { style: { display: "flex", flexDirection: "column" as const, alignItems: "center" } },
          React.createElement(
            "span",
            {
              style: {
                fontFamily: "Cormorant Garamond",
                fontSize: 22,
                fontWeight: 600,
                color: "#F5F1EB",
              },
            },
            formatNumber(booksCount)
          ),
          React.createElement(
            "span",
            {
              style: {
                fontSize: 9,
                letterSpacing: 2,
                textTransform: "uppercase" as const,
                color: "#475569",
                marginTop: 2,
              },
            },
            "livres lus"
          )
        ),
        // Pages stat
        React.createElement(
          "div",
          { style: { display: "flex", flexDirection: "column" as const, alignItems: "center" } },
          React.createElement(
            "span",
            {
              style: {
                fontFamily: "Cormorant Garamond",
                fontSize: 22,
                fontWeight: 600,
                color: "#F5F1EB",
              },
            },
            formatNumber(totalPages)
          ),
          React.createElement(
            "span",
            {
              style: {
                fontSize: 9,
                letterSpacing: 2,
                textTransform: "uppercase" as const,
                color: "#475569",
                marginTop: 2,
              },
            },
            "pages lues"
          )
        ),
        // Hours stat
        React.createElement(
          "div",
          { style: { display: "flex", flexDirection: "column" as const, alignItems: "center" } },
          React.createElement(
            "span",
            {
              style: {
                fontFamily: "Cormorant Garamond",
                fontSize: 22,
                fontWeight: 600,
                color: "#F5F1EB",
              },
            },
            totalHours
          ),
          React.createElement(
            "span",
            {
              style: {
                fontSize: 9,
                letterSpacing: 2,
                textTransform: "uppercase" as const,
                color: "#475569",
                marginTop: 2,
              },
            },
            "de lecture"
          )
        )
      )
    ),

    // Bottom bar
    React.createElement("div", {
      style: {
        position: "absolute" as const,
        bottom: 0,
        left: 0,
        right: 0,
        height: 3,
        background: "linear-gradient(90deg, transparent, #6B988D, transparent)",
        opacity: 0.4,
      },
    }),

    // Bottom label
    React.createElement(
      "div",
      {
        style: {
          position: "absolute" as const,
          bottom: 18,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          fontSize: 9,
          letterSpacing: 3,
          textTransform: "uppercase" as const,
          color: "#334155",
        },
      },
      "lexday.app"
    )
  );
}

// ── Main handler ────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // ── Auth ──
  const authHeader = req.headers.get("authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  const supabaseUser = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabaseUser.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Non autorisé" }, 401);
  }

  // Service-role client for data queries & storage
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    global: { fetch },
  });

  try {
    const body = await req.json();
    const { badge_id } = body;

    if (!badge_id || typeof badge_id !== "string") {
      return jsonResponse({ error: "badge_id requis" }, 400);
    }

    const storagePath = `${user.id}/${badge_id}.png`;
    const storageUrl = `${SUPABASE_URL}/storage/v1/object/public/badge-cards/${storagePath}`;

    // ── Cache check ──
    if (!body.force) {
      try {
        const cachedRes = await fetch(storageUrl, { method: "HEAD" });
        if (cachedRes.ok) {
          return jsonResponse({ url: storageUrl });
        }
      } catch {
        // Cache miss, continue to generate
      }
    }

    // ── Fetch badge + user stats in parallel ──
    const [badgeRes, booksRes, sessionsRes] = await Promise.all([
      supabase
        .from("badges")
        .select("id, name, description, icon, category, color")
        .eq("id", badge_id)
        .single(),

      supabase
        .from("user_books")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("status", "finished"),

      supabase
        .from("reading_sessions")
        .select("start_time, end_time, start_page, end_page")
        .eq("user_id", user.id)
        .not("end_time", "is", null),
    ]);

    if (badgeRes.error || !badgeRes.data) {
      return jsonResponse({ error: "Badge non trouvé" }, 404);
    }

    const badge = badgeRes.data as BadgeData;
    const booksCount = booksRes.count ?? 0;

    // Compute total pages and reading minutes
    let totalMinutes = 0;
    let totalPages = 0;
    for (const s of sessionsRes.data ?? []) {
      if (s.start_time && s.end_time) {
        const st = new Date(s.start_time).getTime();
        const et = new Date(s.end_time).getTime();
        const diff = (et - st) / 60000;
        if (diff > 0 && diff < 1440) {
          // Cap at 24h per session (sanity check)
          totalMinutes += diff;
        }
      }
      if (s.start_page != null && s.end_page != null) {
        const pageDiff = s.end_page - s.start_page;
        if (pageDiff > 0) totalPages += pageDiff;
      }
    }

    const totalHoursStr = formatHours(totalMinutes);
    const stars = generateStars(badge_id, 50);

    // ── Load fonts ──
    const [cormorantBoldData, cormorantSemiBoldData, dmSansLightData, dmSansRegularData, dmSansMediumData] =
      await Promise.all([
        cormorantBold,
        cormorantSemiBold,
        dmSansLight,
        dmSansRegular,
        dmSansMedium,
      ]);

    // ── Generate image ──
    const imageResponse = new ImageResponse(
      BadgeCard({
        badge,
        booksCount,
        totalPages,
        totalHours: totalHoursStr,
        stars,
      }),
      {
        width: 420,
        height: 600,
        emoji: "twemoji",
        fonts: [
          {
            name: "Cormorant Garamond",
            data: cormorantBoldData,
            weight: 700,
            style: "normal",
          },
          {
            name: "Cormorant Garamond",
            data: cormorantSemiBoldData,
            weight: 600,
            style: "normal",
          },
          {
            name: "DM Sans",
            data: dmSansLightData,
            weight: 300,
            style: "normal",
          },
          {
            name: "DM Sans",
            data: dmSansRegularData,
            weight: 400,
            style: "normal",
          },
          {
            name: "DM Sans",
            data: dmSansMediumData,
            weight: 500,
            style: "normal",
          },
        ],
      }
    );

    // Read the PNG body
    const pngBuffer = await imageResponse.arrayBuffer();
    const pngBytes = new Uint8Array(pngBuffer);

    // ── Upload to storage ──
    const { error: uploadError } = await supabase.storage
      .from("badge-cards")
      .upload(storagePath, pngBytes, {
        contentType: "image/png",
        cacheControl: "31536000",
        upsert: true,
      });

    if (uploadError) {
      console.error("Upload error:", uploadError);
      return jsonResponse({ error: "Erreur upload image" }, 500);
    }

    return jsonResponse({ url: storageUrl });
  } catch (error) {
    console.error("Badge card error:", error);
    return jsonResponse({ error: "Erreur interne" }, 500);
  }
});

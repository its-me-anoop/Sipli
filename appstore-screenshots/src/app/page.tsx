"use client";

import React, { useRef, useEffect, useState, useCallback } from "react";
import { toPng } from "html-to-image";

/* ─── Canvas dimensions (design at largest iPhone size) ─── */
const W = 1320;
const H = 2868;

/* ─── Export sizes (Apple required, iPhone portrait) ─── */
const SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

type Size = (typeof SIZES)[number];

/* ─── Phone mockup measurements ─── */
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

/* ─── Brand tokens ─── */
const BRAND = {
  lagoon: "#1C78F5",
  mint: "#30C2A3",
  lavender: "#7D70F2",
  coral: "#F05447",
  sun: "#FAAB2B",
  peach: "#F58259",
  darkBg1: "#0F2947",
  darkBg2: "#051224",
  deepNavy: "#0A1929",
};

/* ═══════════════════════════════════════════════════════
   SHARED EXPORT HELPER
   ═══════════════════════════════════════════════════════ */

async function captureAndDownload(
  el: HTMLElement,
  filename: string,
  size: Size,
): Promise<void> {
  el.style.left = "0px";
  el.style.opacity = "1";
  el.style.zIndex = "-1";

  const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };

  try {
    // Double-call trick: first warms fonts/images, second produces clean output
    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);

    const img = new Image();
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error(`Failed to load captured image for ${filename}`));
      img.src = dataUrl;
    });

    const canvas = document.createElement("canvas");
    canvas.width = size.w;
    canvas.height = size.h;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Failed to get canvas 2d context");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, 0, 0, size.w, size.h);

    const resizedUrl = canvas.toDataURL("image/png");
    const link = document.createElement("a");
    link.download = `${filename}-${size.w}x${size.h}.png`;
    link.href = resizedUrl;
    link.click();
  } finally {
    el.style.left = "-9999px";
    el.style.opacity = "";
    el.style.zIndex = "";
  }
}

/* ═══════════════════════════════════════════════════════
   COMPONENTS
   ═══════════════════════════════════════════════════════ */

function Phone({
  src,
  alt,
  style,
  className = "",
}: {
  src: string;
  alt: string;
  style?: React.CSSProperties;
  className?: string;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ aspectRatio: `${MK_W}/${MK_H}`, ...style }}
    >
      <img
        src="/mockup.png"
        alt=""
        className="block w-full h-full"
        draggable={false}
      />
      <div
        className="absolute z-10 overflow-hidden"
        style={{
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={src}
          alt={alt}
          className="block w-full h-full object-cover object-top"
          draggable={false}
        />
      </div>
    </div>
  );
}

function Caption({
  label,
  headline,
  align = "center",
  light = false,
}: {
  label: string;
  headline: React.ReactNode;
  align?: "center" | "left" | "right";
  light?: boolean;
}) {
  const labelColor = light ? "rgba(28,120,245,0.9)" : "rgba(48,194,163,0.95)";
  const headlineColor = light ? "#0A1929" : "#FFFFFF";
  return (
    <div style={{ textAlign: align }}>
      <div
        style={{
          fontSize: W * 0.028,
          fontWeight: 600,
          color: labelColor,
          letterSpacing: "0.06em",
          textTransform: "uppercase",
          marginBottom: W * 0.015,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: W * 0.09,
          fontWeight: 700,
          lineHeight: 1.0,
          color: headlineColor,
          letterSpacing: "-0.02em",
        }}
      >
        {headline}
      </div>
    </div>
  );
}

function Blob({
  color,
  size,
  x,
  y,
  blur = 120,
  opacity = 0.4,
}: {
  color: string;
  size: number;
  x: number;
  y: number;
  blur?: number;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        filter: `blur(${blur}px)`,
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}

/* ═══════════════════════════════════════════════════════
   SLIDE BACKGROUNDS
   ═══════════════════════════════════════════════════════ */

function DarkOceanBg({ children, blobs }: { children: React.ReactNode; blobs?: React.ReactNode }) {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, ${BRAND.darkBg1} 0%, ${BRAND.deepNavy} 40%, ${BRAND.darkBg2} 100%)`,
      }}
    >
      {blobs}
      <div style={{ position: "relative", zIndex: 1, width: "100%", height: "100%" }}>
        {children}
      </div>
    </div>
  );
}

function LightBg({ children, blobs }: { children: React.ReactNode; blobs?: React.ReactNode }) {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, #EDF3FF 0%, #D6E6FF 50%, #C4DAFF 100%)`,
      }}
    >
      {blobs}
      <div style={{ position: "relative", zIndex: 1, width: "100%", height: "100%" }}>
        {children}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SLIDES
   ═══════════════════════════════════════════════════════ */

/* ── 1. HERO ── */
function Slide1() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.lagoon} size={600} x={-200} y={200} blur={160} opacity={0.3} />
          <Blob color={BRAND.mint} size={500} x={700} y={1400} blur={140} opacity={0.2} />
          <Blob color={BRAND.lavender} size={400} x={900} y={400} blur={130} opacity={0.15} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", height: "100%", paddingTop: H * 0.06 }}>
        <div
          style={{
            width: W * 0.22,
            aspectRatio: "1 / 1",
            borderRadius: W * 0.05,
            overflow: "hidden",
            boxShadow: "0 20px 60px rgba(28,120,245,0.3)",
            marginBottom: W * 0.035,
            flexShrink: 0,
          }}
        >
          <img src="/app-icon.png" alt="Sipli" style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }} />
        </div>

        <div style={{ marginTop: W * 0.01 }}>
          <Caption
            label="Smart Hydration"
            headline={
              <>
                Stay Hydrated,
                <br />
                Effortlessly
              </>
            }
          />
        </div>

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone
            src="/screenshots/home-dark.png"
            alt="Sipli home screen"
            style={{
              width: "82%",
              transform: "translateY(12%)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 2. HYDRATION COACH ── */
function Slide2() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.lavender} size={550} x={-150} y={600} blur={150} opacity={0.35} />
          <Blob color={BRAND.lagoon} size={450} x={600} y={1800} blur={130} opacity={0.25} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <Caption
          label="AI-Powered"
          headline={
            <>
              A Coach That
              <br />
              Knows You
            </>
          }
          align="left"
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "flex-end", width: "100%" }}>
          <Phone
            src="/screenshots/home-dark-scrolled.png"
            alt="Hydration coach"
            style={{
              width: "86%",
              transform: "translateX(8%) translateY(10%)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 3. BEVERAGES ── */
function Slide3() {
  return (
    <LightBg
      blobs={
        <>
          <Blob color={BRAND.lagoon} size={500} x={-100} y={800} blur={160} opacity={0.15} />
          <Blob color={BRAND.mint} size={400} x={800} y={1600} blur={140} opacity={0.12} />
          <Blob color={BRAND.lavender} size={350} x={400} y={300} blur={120} opacity={0.1} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <Caption
          label="All Beverages"
          headline={
            <>
              Not Just
              <br />
              Water
            </>
          }
          light
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%", position: "relative" }}>
          <Phone
            src="/screenshots/log-intake-light.png"
            alt="Log intake light"
            style={{
              width: "65%",
              position: "absolute",
              left: "-6%",
              bottom: "-6%",
              transform: "rotate(-4deg)",
              opacity: 0.6,
            }}
          />
          <Phone
            src="/screenshots/log-intake-dark.png"
            alt="Log intake"
            style={{
              width: "80%",
              position: "absolute",
              right: "-2%",
              bottom: "-8%",
            }}
          />
        </div>
      </div>
    </LightBg>
  );
}

/* ── 4. INSIGHTS ── */
function Slide4() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.lagoon} size={600} x={500} y={300} blur={170} opacity={0.3} />
          <Blob color={BRAND.mint} size={450} x={-200} y={1500} blur={140} opacity={0.2} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <Caption
          label="Weekly Insights"
          headline={
            <>
              See Your
              <br />
              Progress
            </>
          }
          align="right"
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "flex-start", width: "100%" }}>
          <Phone
            src="/screenshots/insights-dark.png"
            alt="Weekly insights"
            style={{
              width: "86%",
              transform: "translateX(-6%) translateY(10%)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 5. BEVERAGE BREAKDOWN ── */
function Slide5() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.peach} size={500} x={-100} y={500} blur={150} opacity={0.2} />
          <Blob color={BRAND.sun} size={400} x={700} y={1200} blur={130} opacity={0.15} />
          <Blob color={BRAND.lagoon} size={350} x={200} y={2000} blur={120} opacity={0.2} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <Caption
          label="Beverage Breakdown"
          headline={
            <>
              Every Sip,
              <br />
              Visualized
            </>
          }
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone
            src="/screenshots/insights-dark-scrolled.png"
            alt="Beverage breakdown"
            style={{
              width: "82%",
              transform: "translateY(12%)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 6. DIARY ── */
function Slide6() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.mint} size={550} x={600} y={600} blur={160} opacity={0.25} />
          <Blob color={BRAND.lagoon} size={400} x={-100} y={1800} blur={130} opacity={0.2} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <Caption
          label="Hydration Diary"
          headline={
            <>
              Look Back
              <br />
              Any Day
            </>
          }
          align="left"
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone
            src="/screenshots/diary-dark.png"
            alt="Hydration diary"
            style={{
              width: "82%",
              transform: "translateY(12%)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 7. WIDGETS ── */
function Slide7() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.lagoon} size={600} x={100} y={400} blur={170} opacity={0.25} />
          <Blob color={BRAND.lavender} size={450} x={600} y={1600} blur={140} opacity={0.2} />
          <Blob color={BRAND.mint} size={300} x={-100} y={2200} blur={120} opacity={0.15} />
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <Caption
          label="Widgets"
          headline={
            <>
              One Glance
              <br />
              Away
            </>
          }
        />

        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%", position: "relative" }}>
          <Phone
            src="/screenshots/lockscreen.png"
            alt="Lock screen widgets"
            style={{
              width: "62%",
              position: "absolute",
              left: "-4%",
              bottom: "-4%",
              transform: "rotate(-3deg)",
              opacity: 0.6,
            }}
          />
          <Phone
            src="/screenshots/widgets.png"
            alt="Home screen widgets"
            style={{
              width: "78%",
              position: "absolute",
              right: "-2%",
              bottom: "-6%",
              transform: "rotate(2deg)",
            }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ── 8. MORE FEATURES ── */
function Slide8() {
  const features = [
    "Weather-Adjusted Goals",
    "HealthKit Sync",
    "Dark & Light Mode",
    "Hydration Heatmap",
    "Activity Tracking",
    "Smart Reminders",
    "Daily Log",
    "Multiple Beverages",
  ];
  const comingSoon = ["Apple Watch App", "Shortcuts"];

  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(175deg, #080E1A 0%, ${BRAND.darkBg2} 50%, #060C18 100%)`,
      }}
    >
      <Blob color={BRAND.lagoon} size={700} x={W / 2 - 350} y={H / 2 - 350} blur={200} opacity={0.12} />
      <Blob color={BRAND.lavender} size={400} x={-100} y={200} blur={150} opacity={0.1} />
      <Blob color={BRAND.mint} size={350} x={900} y={2200} blur={130} opacity={0.1} />

      <div
        style={{
          position: "relative",
          zIndex: 1,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          height: "100%",
          padding: `0 ${W * 0.1}px`,
          gap: W * 0.06,
        }}
      >
        <div
          style={{
            width: W * 0.24,
            aspectRatio: "1 / 1",
            borderRadius: W * 0.055,
            overflow: "hidden",
            boxShadow: "0 20px 80px rgba(28,120,245,0.25)",
            flexShrink: 0,
          }}
        >
          <img src="/app-icon.png" alt="Sipli" style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }} />
        </div>

        <Caption
          label="Sipli"
          headline={
            <>
              And So
              <br />
              Much More
            </>
          }
        />

        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            gap: W * 0.022,
            maxWidth: W * 0.85,
          }}
        >
          {features.map((f) => (
            <div
              key={f}
              style={{
                padding: `${W * 0.018}px ${W * 0.035}px`,
                borderRadius: W * 0.06,
                background: "rgba(255,255,255,0.08)",
                border: "1px solid rgba(255,255,255,0.12)",
                color: "rgba(255,255,255,0.85)",
                fontSize: W * 0.03,
                fontWeight: 500,
                whiteSpace: "nowrap",
              }}
            >
              {f}
            </div>
          ))}
        </div>

        <div style={{ textAlign: "center" }}>
          <div
            style={{
              fontSize: W * 0.024,
              fontWeight: 600,
              color: "rgba(255,255,255,0.4)",
              letterSpacing: "0.08em",
              textTransform: "uppercase",
              marginBottom: W * 0.02,
            }}
          >
            Coming Soon
          </div>
          <div
            style={{
              display: "flex",
              flexWrap: "wrap",
              justifyContent: "center",
              gap: W * 0.022,
            }}
          >
            {comingSoon.map((f) => (
              <div
                key={f}
                style={{
                  padding: `${W * 0.018}px ${W * 0.035}px`,
                  borderRadius: W * 0.06,
                  background: "rgba(255,255,255,0.04)",
                  border: "1px solid rgba(255,255,255,0.06)",
                  color: "rgba(255,255,255,0.35)",
                  fontSize: W * 0.03,
                  fontWeight: 500,
                  whiteSpace: "nowrap",
                }}
              >
                {f}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREENSHOT REGISTRY
   ═══════════════════════════════════════════════════════ */

const SCREENSHOTS: { name: string; component: React.FC }[] = [
  { name: "hero", component: Slide1 },
  { name: "coach", component: Slide2 },
  { name: "beverages", component: Slide3 },
  { name: "insights", component: Slide4 },
  { name: "breakdown", component: Slide5 },
  { name: "diary", component: Slide6 },
  { name: "widgets", component: Slide7 },
  { name: "more", component: Slide8 },
];

/* ═══════════════════════════════════════════════════════
   PREVIEW + EXPORT
   ═══════════════════════════════════════════════════════ */

function ScreenshotPreview({
  entry,
  index,
  exportRef,
}: {
  entry: (typeof SCREENSHOTS)[number];
  index: number;
  exportRef: React.RefObject<HTMLDivElement | null>;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);
  const [exporting, setExporting] = useState(false);
  const Component = entry.component;

  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => {
      const { width } = e.contentRect;
      setScale(width / W);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const handleExport = useCallback(async () => {
    const el = exportRef.current;
    if (!el || exporting) return;
    setExporting(true);

    const prefix = String(index + 1).padStart(2, "0");
    try {
      for (const size of SIZES) {
        await captureAndDownload(el, `${prefix}-${entry.name}`, size);
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch (err) {
      console.error(`Export failed for ${entry.name}:`, err);
      alert(`Export failed for "${entry.name}". Check console for details.`);
    } finally {
      setExporting(false);
    }
  }, [entry.name, exporting, index, exportRef]);

  return (
    <div>
      <div
        ref={wrapRef}
        onClick={handleExport}
        style={{
          width: "100%",
          aspectRatio: `${W}/${H}`,
          overflow: "hidden",
          borderRadius: 12,
          cursor: exporting ? "wait" : "pointer",
          border: "1px solid rgba(255,255,255,0.1)",
          position: "relative",
        }}
      >
        <div
          style={{
            width: W,
            height: H,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          <Component />
        </div>
      </div>

      <div
        style={{
          textAlign: "center",
          marginTop: 8,
          fontSize: 13,
          color: "rgba(255,255,255,0.6)",
          fontWeight: 500,
        }}
      >
        {String(index + 1).padStart(2, "0")} — {entry.name}
        {exporting && " (exporting...)"}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   PAGE
   ═══════════════════════════════════════════════════════ */

export default function ScreenshotsPage() {
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [exportingAll, setExportingAll] = useState(false);
  const [selectedSize, setSelectedSize] = useState(0);

  const exportAll = useCallback(async () => {
    if (exportingAll) return;
    setExportingAll(true);

    const size = SIZES[selectedSize];
    try {
      for (let i = 0; i < SCREENSHOTS.length; i++) {
        const el = exportRefs.current[i];
        if (!el) continue;

        const prefix = String(i + 1).padStart(2, "0");
        await captureAndDownload(el, `${prefix}-${SCREENSHOTS[i].name}`, size);
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch (err) {
      console.error("Export all failed:", err);
      alert("Export failed. Check console for details.");
    } finally {
      setExportingAll(false);
    }
  }, [exportingAll, selectedSize]);

  return (
    <div style={{ minHeight: "100vh", background: "#0A0A0A", padding: "40px 32px" }}>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginBottom: 32,
          flexWrap: "wrap",
          gap: 16,
        }}
      >
        <h1 style={{ color: "white", fontSize: 24, fontWeight: 700, margin: 0 }}>
          Sipli — App Store Screenshots
        </h1>
        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <select
            value={selectedSize}
            onChange={(e) => setSelectedSize(Number(e.target.value))}
            style={{
              background: "rgba(255,255,255,0.1)",
              color: "white",
              border: "1px solid rgba(255,255,255,0.2)",
              borderRadius: 8,
              padding: "8px 12px",
              fontSize: 14,
            }}
          >
            {SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} ({s.w}x{s.h})
              </option>
            ))}
          </select>
          <button
            onClick={exportAll}
            disabled={exportingAll}
            style={{
              background: exportingAll ? "rgba(28,120,245,0.5)" : BRAND.lagoon,
              color: "white",
              border: "none",
              borderRadius: 8,
              padding: "10px 20px",
              fontSize: 14,
              fontWeight: 600,
              cursor: exportingAll ? "wait" : "pointer",
            }}
          >
            {exportingAll ? "Exporting..." : `Export All (${SIZES[selectedSize].label})`}
          </button>
        </div>
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))",
          gap: 24,
        }}
      >
        {SCREENSHOTS.map((entry, i) => (
          <ScreenshotPreview
            key={entry.name}
            entry={entry}
            index={i}
            exportRef={{ current: exportRefs.current[i] ?? null }}
          />
        ))}
      </div>

      {/* Single set of off-screen export containers (shared by per-slide and export-all) */}
      {SCREENSHOTS.map((entry, i) => {
        const Component = entry.component;
        return (
          <div
            key={`export-${entry.name}`}
            ref={(el) => { exportRefs.current[i] = el; }}
            style={{
              position: "absolute",
              left: "-9999px",
              top: 0,
              width: W,
              height: H,
              fontFamily: "Inter, sans-serif",
            }}
          >
            <Component />
          </div>
        );
      })}

      <p style={{ textAlign: "center", color: "rgba(255,255,255,0.3)", marginTop: 40, fontSize: 13 }}>
        Click any screenshot to export all 4 sizes. Use &ldquo;Export All&rdquo; for a single size.
      </p>
    </div>
  );
}

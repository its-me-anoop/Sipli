"use client";

import React, { useRef, useCallback, useEffect, useState } from "react";
import { toPng } from "html-to-image";

// ─── Design Canvas (6.9" iPhone) ───────────────────────────────
const W = 1320;
const H = 2868;

// ─── Export Sizes (Apple Required) ─────────────────────────────
const SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

// ─── Phone Mockup Constants ───────────────────────────────────
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// ─── Brand Colors ─────────────────────────────────────────────
const COLORS = {
  lagoon: "#1C79F5",
  mint: "#31C2A3",
  coral: "#F05447",
  peach: "#F5825A",
  sun: "#FAAB2C",
  lavender: "#7D70F3",
  dark: "#0A1628",
  darkBlue: "#0F2245",
};

// ─── Phone Component ──────────────────────────────────────────
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

// ─── Caption Component ────────────────────────────────────────
function Caption({
  label,
  headline,
  color = "#fff",
  labelColor,
  align = "center",
}: {
  label?: string;
  headline: React.ReactNode;
  color?: string;
  labelColor?: string;
  align?: "center" | "left";
}) {
  return (
    <div
      style={{
        textAlign: align,
        padding: `0 ${W * 0.06}px`,
      }}
    >
      {label && (
        <div
          style={{
            fontSize: W * 0.03,
            fontWeight: 600,
            color: labelColor || color,
            opacity: 0.8,
            letterSpacing: "0.05em",
            textTransform: "uppercase",
            marginBottom: W * 0.02,
          }}
        >
          {label}
        </div>
      )}
      <div
        style={{
          fontSize: W * 0.09,
          fontWeight: 700,
          color,
          lineHeight: 1.0,
          letterSpacing: "-0.02em",
        }}
      >
        {headline}
      </div>
    </div>
  );
}

// ─── Decorative Blob ──────────────────────────────────────────
function Blob({
  color,
  size,
  top,
  left,
  blur = 120,
  opacity = 0.3,
}: {
  color: string;
  size: number;
  top: string;
  left: string;
  blur?: number;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        top,
        left,
        filter: `blur(${blur}px)`,
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}

// ─── Slide 1: Hero ────────────────────────────────────────────
function Slide1() {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(165deg, #e8f4ff 0%, #d0e8ff 25%, ${COLORS.lagoon}22 50%, ${COLORS.mint}33 100%)`,
      }}
    >
      <Blob color={COLORS.lagoon} size={600} top="-10%" left="-15%" blur={180} opacity={0.15} />
      <Blob color={COLORS.mint} size={500} top="15%" left="60%" blur={150} opacity={0.12} />
      <Blob color={COLORS.lavender} size={400} top="50%" left="-10%" blur={160} opacity={0.08} />

      <div
        style={{
          position: "relative",
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          paddingTop: H * 0.05,
          height: "100%",
        }}
      >
        {/* App Icon */}
        <div
          style={{
            width: W * 0.17,
            height: W * 0.17,
            borderRadius: W * 0.04,
            overflow: "hidden",
            boxShadow: "0 20px 60px rgba(28, 121, 245, 0.3)",
            marginBottom: W * 0.03,
          }}
        >
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
            draggable={false}
          />
        </div>

        {/* App Name */}
        <div
          style={{
            fontSize: W * 0.05,
            fontWeight: 700,
            color: COLORS.lagoon,
            letterSpacing: "0.02em",
            marginBottom: W * 0.03,
          }}
        >
          Sipli
        </div>

        <Caption
          headline={
            <>
              Stay hydrated,
              <br />
              effortlessly.
            </>
          }
          color={COLORS.dark}
        />

        <div
          style={{
            fontSize: W * 0.032,
            color: "#5a7a9a",
            marginTop: W * 0.02,
            textAlign: "center",
            lineHeight: 1.5,
            padding: `0 ${W * 0.1}px`,
          }}
        >
          Smart hydration tracking that
          <br />
          adapts to your life.
        </div>

        {/* Phone */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(18%)",
            width: "82%",
          }}
        >
          <Phone src="/screenshots/dashboard-light.png" alt="Dashboard" />
        </div>
      </div>
    </div>
  );
}

// ─── Slide 2: AI Coach (Dark) ─────────────────────────────────
function Slide2() {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, ${COLORS.dark} 0%, ${COLORS.darkBlue} 40%, #0B2E5C 100%)`,
      }}
    >
      <Blob color={COLORS.lagoon} size={700} top="5%" left="50%" blur={200} opacity={0.12} />
      <Blob color={COLORS.mint} size={500} top="60%" left="-20%" blur={180} opacity={0.1} />
      <Blob color={COLORS.lavender} size={350} top="30%" left="70%" blur={150} opacity={0.08} />

      <div
        style={{
          position: "relative",
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          paddingTop: H * 0.07,
          height: "100%",
        }}
      >
        <Caption
          label="AI-Powered"
          headline={
            <>
              Your personal
              <br />
              hydration coach.
            </>
          }
          color="#fff"
          labelColor={COLORS.mint}
        />

        <div
          style={{
            fontSize: W * 0.034,
            color: "rgba(255,255,255,0.5)",
            marginTop: W * 0.025,
            textAlign: "center",
            lineHeight: 1.5,
            padding: `0 ${W * 0.08}px`,
          }}
        >
          Weather-aware tips that keep
          <br />
          you on track all day.
        </div>

        {/* Phone */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(10%)",
            width: "84%",
          }}
        >
          <Phone src="/screenshots/dashboard-dark.png" alt="AI Coach" />
        </div>
      </div>
    </div>
  );
}

// ─── Slide 3: Insights ────────────────────────────────────────
function Slide3() {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(160deg, #f0f7ff 0%, #ddeeff 30%, #c8e0ff 60%, ${COLORS.lagoon}18 100%)`,
      }}
    >
      <Blob color={COLORS.lagoon} size={550} top="-5%" left="55%" blur={170} opacity={0.13} />
      <Blob color={COLORS.sun} size={400} top="25%" left="-15%" blur={160} opacity={0.08} />
      <Blob color={COLORS.mint} size={450} top="65%" left="60%" blur={180} opacity={0.1} />

      <div
        style={{
          position: "relative",
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          paddingTop: H * 0.07,
          height: "100%",
        }}
      >
        <Caption
          label="Insights"
          headline={
            <>
              See your habits
              <br />
              at a glance.
            </>
          }
          color={COLORS.dark}
          labelColor={COLORS.lagoon}
        />

        <div
          style={{
            fontSize: W * 0.034,
            color: "#5a7a9a",
            marginTop: W * 0.025,
            textAlign: "center",
            lineHeight: 1.5,
            padding: `0 ${W * 0.08}px`,
          }}
        >
          Heatmaps and breakdowns
          <br />
          that reveal your patterns.
        </div>

        {/* Phone */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: "82%",
          }}
        >
          <Phone src="/screenshots/insights.png" alt="Insights" />
        </div>
      </div>
    </div>
  );
}

// ─── Slide 4: Diary ───────────────────────────────────────────
function Slide4() {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(155deg, #f8fbff 0%, #eaf2ff 30%, #dce9ff 60%, ${COLORS.lagoon}10 100%)`,
      }}
    >
      <Blob color={COLORS.lavender} size={500} top="0%" left="60%" blur={170} opacity={0.1} />
      <Blob color={COLORS.lagoon} size={450} top="40%" left="-15%" blur={160} opacity={0.1} />
      <Blob color={COLORS.peach} size={350} top="70%" left="65%" blur={150} opacity={0.07} />

      <div
        style={{
          position: "relative",
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          paddingTop: H * 0.07,
          height: "100%",
        }}
      >
        <Caption
          label="Diary"
          headline={
            <>
              Every sip,
              <br />
              remembered.
            </>
          }
          color={COLORS.dark}
          labelColor={COLORS.lavender}
        />

        <div
          style={{
            fontSize: W * 0.034,
            color: "#5a7a9a",
            marginTop: W * 0.025,
            textAlign: "center",
            lineHeight: 1.5,
            padding: `0 ${W * 0.08}px`,
          }}
        >
          Browse your full history
          <br />
          with calendar navigation.
        </div>

        {/* Phone */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(14%)",
            width: "82%",
          }}
        >
          <Phone src="/screenshots/diary.png" alt="Diary" />
        </div>
      </div>
    </div>
  );
}

// ─── Slide 5: More Features (Dark CTA) ───────────────────────
function Slide5() {
  const features = [
    "18 Beverage Types",
    "Smart Reminders",
    "Apple Health Sync",
    "Weather Adaptation",
    "Dark Mode",
    "Privacy First",
    "Hydration Heatmap",
    "Activity Tracking",
  ];
  const comingSoon = ["Apple Watch", "Widgets"];

  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(170deg, ${COLORS.dark} 0%, #0D1F3C 40%, ${COLORS.darkBlue} 100%)`,
      }}
    >
      <Blob color={COLORS.lagoon} size={600} top="-5%" left="-20%" blur={200} opacity={0.15} />
      <Blob color={COLORS.mint} size={500} top="50%" left="60%" blur={180} opacity={0.1} />
      <Blob color={COLORS.lavender} size={400} top="80%" left="-10%" blur={170} opacity={0.08} />

      <div
        style={{
          position: "relative",
          zIndex: 2,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          paddingTop: H * 0.12,
          height: "100%",
        }}
      >
        {/* App Icon */}
        <div
          style={{
            width: W * 0.22,
            height: W * 0.22,
            borderRadius: W * 0.05,
            overflow: "hidden",
            boxShadow: "0 20px 80px rgba(28, 121, 245, 0.4)",
            marginBottom: W * 0.06,
          }}
        >
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
            draggable={false}
          />
        </div>

        <Caption
          headline={
            <>
              And so much
              <br />
              more.
            </>
          }
          color="#fff"
        />

        {/* Feature pills */}
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            gap: W * 0.025,
            padding: `${W * 0.06}px ${W * 0.08}px 0`,
            maxWidth: W * 0.9,
          }}
        >
          {features.map((f) => (
            <div
              key={f}
              style={{
                padding: `${W * 0.018}px ${W * 0.04}px`,
                borderRadius: W * 0.06,
                background: "rgba(255,255,255,0.08)",
                border: "1px solid rgba(255,255,255,0.12)",
                color: "rgba(255,255,255,0.85)",
                fontSize: W * 0.032,
                fontWeight: 500,
                whiteSpace: "nowrap",
              }}
            >
              {f}
            </div>
          ))}
        </div>

        {/* Coming Soon */}
        <div
          style={{
            marginTop: W * 0.06,
            fontSize: W * 0.028,
            fontWeight: 600,
            color: "rgba(255,255,255,0.35)",
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            marginBottom: W * 0.025,
          }}
        >
          Coming Soon
        </div>
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            gap: W * 0.025,
            padding: `0 ${W * 0.08}px`,
          }}
        >
          {comingSoon.map((f) => (
            <div
              key={f}
              style={{
                padding: `${W * 0.018}px ${W * 0.04}px`,
                borderRadius: W * 0.06,
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.06)",
                color: "rgba(255,255,255,0.4)",
                fontSize: W * 0.032,
                fontWeight: 500,
                whiteSpace: "nowrap",
              }}
            >
              {f}
            </div>
          ))}
        </div>

        {/* Download CTA */}
        <div
          style={{
            marginTop: W * 0.08,
            padding: `${W * 0.025}px ${W * 0.08}px`,
            borderRadius: W * 0.06,
            background: `linear-gradient(135deg, ${COLORS.lagoon}, ${COLORS.mint})`,
            color: "#fff",
            fontSize: W * 0.038,
            fontWeight: 700,
            boxShadow: `0 12px 40px ${COLORS.lagoon}66`,
          }}
        >
          Download Sipli Free
        </div>
      </div>
    </div>
  );
}

// ─── Screenshot Registry ──────────────────────────────────────
const SCREENSHOTS: { name: string; Component: React.FC }[] = [
  { name: "hero", Component: Slide1 },
  { name: "ai-coach", Component: Slide2 },
  { name: "insights", Component: Slide3 },
  { name: "diary", Component: Slide4 },
  { name: "more-features", Component: Slide5 },
];

// ─── Preview Card with ResizeObserver Scaling ─────────────────
function ScreenshotPreview({
  name,
  Component,
  index,
  exportRef,
}: {
  name: string;
  Component: React.FC;
  index: number;
  exportRef: React.RefObject<Map<string, HTMLDivElement>>;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => {
      const cw = entry.contentRect.width;
      setScale(cw / W);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div className="flex flex-col items-center gap-3">
      {/* Preview */}
      <div
        ref={containerRef}
        className="w-full rounded-xl overflow-hidden shadow-lg border border-gray-200"
        style={{ aspectRatio: `${W}/${H}` }}
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

      {/* Label */}
      <div className="text-sm text-gray-500 font-medium">
        {String(index + 1).padStart(2, "0")} — {name}
      </div>

      {/* Offscreen export target */}
      <div
        ref={(el) => {
          if (el && exportRef.current) {
            exportRef.current.set(name, el);
          }
        }}
        style={{
          position: "absolute",
          left: -9999,
          top: 0,
          width: W,
          height: H,
          fontFamily: "Inter, sans-serif",
        }}
      >
        <Component />
      </div>
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────
export default function ScreenshotsPage() {
  const exportRefs = useRef<Map<string, HTMLDivElement>>(new Map());
  const [selectedSize, setSelectedSize] = useState(0);
  const [exporting, setExporting] = useState(false);
  const [progress, setProgress] = useState("");

  const exportAll = useCallback(async () => {
    setExporting(true);
    const size = SIZES[selectedSize];

    for (let i = 0; i < SCREENSHOTS.length; i++) {
      const { name } = SCREENSHOTS[i];
      const el = exportRefs.current.get(name);
      if (!el) continue;

      setProgress(`Exporting ${i + 1}/${SCREENSHOTS.length}: ${name}...`);

      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "-1";

      const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };

      try {
        // Double-call trick: first warms up fonts/images
        await toPng(el, opts);
        const dataUrl = await toPng(el, opts);

        const img = new Image();
        img.src = dataUrl;
        await new Promise((resolve) => {
          img.onload = resolve;
        });

        const canvas = document.createElement("canvas");
        canvas.width = size.w;
        canvas.height = size.h;
        const ctx = canvas.getContext("2d")!;
        ctx.drawImage(img, 0, 0, size.w, size.h);

        const blob = await new Promise<Blob>((resolve) =>
          canvas.toBlob((b) => resolve(b!), "image/png")
        );

        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `${String(i + 1).padStart(2, "0")}-${name}-${size.w}x${size.h}.png`;
        a.click();
        URL.revokeObjectURL(url);
      } catch (err) {
        console.error(`Failed to export ${name}:`, err);
      }

      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";

      await new Promise((r) => setTimeout(r, 300));
    }

    setProgress("");
    setExporting(false);
  }, [selectedSize]);

  const exportSingle = useCallback(
    async (name: string, index: number) => {
      setExporting(true);
      const size = SIZES[selectedSize];
      const el = exportRefs.current.get(name);
      if (!el) return;

      setProgress(`Exporting ${name}...`);

      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "-1";

      const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };

      try {
        await toPng(el, opts);
        const dataUrl = await toPng(el, opts);

        const img = new Image();
        img.src = dataUrl;
        await new Promise((resolve) => {
          img.onload = resolve;
        });

        const canvas = document.createElement("canvas");
        canvas.width = size.w;
        canvas.height = size.h;
        const ctx = canvas.getContext("2d")!;
        ctx.drawImage(img, 0, 0, size.w, size.h);

        const blob = await new Promise<Blob>((resolve) =>
          canvas.toBlob((b) => resolve(b!), "image/png")
        );

        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `${String(index + 1).padStart(2, "0")}-${name}-${size.w}x${size.h}.png`;
        a.click();
        URL.revokeObjectURL(url);
      } catch (err) {
        console.error(`Failed to export ${name}:`, err);
      }

      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";

      setProgress("");
      setExporting(false);
    },
    [selectedSize]
  );

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      {/* Toolbar */}
      <div className="max-w-6xl mx-auto mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            Sipli — App Store Screenshots
          </h1>
          <p className="text-gray-500 text-sm mt-1">
            {SCREENSHOTS.length} slides &bull; Click a slide to export individually
          </p>
        </div>

        <div className="flex items-center gap-4">
          <select
            value={selectedSize}
            onChange={(e) => setSelectedSize(Number(e.target.value))}
            className="px-4 py-2 rounded-lg border border-gray-300 bg-white text-sm font-medium"
          >
            {SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}&times;{s.h}
              </option>
            ))}
          </select>

          <button
            onClick={exportAll}
            disabled={exporting}
            className="px-6 py-2 rounded-lg bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {exporting ? "Exporting..." : "Export All"}
          </button>
        </div>
      </div>

      {/* Progress */}
      {progress && (
        <div className="max-w-6xl mx-auto mb-4">
          <div className="px-4 py-2 bg-blue-50 text-blue-700 rounded-lg text-sm font-medium">
            {progress}
          </div>
        </div>
      )}

      {/* Screenshot Grid */}
      <div className="max-w-6xl mx-auto grid grid-cols-5 gap-6">
        {SCREENSHOTS.map(({ name, Component }, i) => (
          <div
            key={name}
            className="cursor-pointer hover:opacity-90 transition-opacity"
            onClick={() => !exporting && exportSingle(name, i)}
          >
            <ScreenshotPreview
              name={name}
              Component={Component}
              index={i}
              exportRef={exportRefs}
            />
          </div>
        ))}
      </div>
    </div>
  );
}

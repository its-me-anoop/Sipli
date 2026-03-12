"use client";

import React, { useRef, useEffect, useState, useCallback } from "react";
import { toPng } from "html-to-image";

/* ═══════════════════════════════════════════════════════
   DIMENSIONS & SIZES
   ═══════════════════════════════════════════════════════ */

/* ─── iPhone ─── */
const W = 1320;
const H = 2868;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

/* ─── iPad ─── */
const IW = 2048;
const IH = 2732;

const IPAD_SIZES = [
  { label: 'iPad Pro 12.9"', w: 2048, h: 2732 },
  { label: 'iPad Pro 11"', w: 1668, h: 2388 },
] as const;

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
  sourceW: number,
  sourceH: number,
  targetW: number,
  targetH: number,
): Promise<void> {
  el.style.left = "0px";
  el.style.opacity = "1";
  el.style.zIndex = "-1";

  const opts = { width: sourceW, height: sourceH, pixelRatio: 1, cacheBust: true };

  try {
    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);

    const img = new Image();
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error(`Failed to load captured image for ${filename}`));
      img.src = dataUrl;
    });

    const canvas = document.createElement("canvas");
    canvas.width = targetW;
    canvas.height = targetH;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Failed to get canvas 2d context");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, 0, 0, targetW, targetH);

    const resizedUrl = canvas.toDataURL("image/png");
    const link = document.createElement("a");
    link.download = `${filename}-${targetW}x${targetH}.png`;
    link.href = resizedUrl;
    link.click();
  } finally {
    el.style.left = "-9999px";
    el.style.opacity = "";
    el.style.zIndex = "";
  }
}

/* ═══════════════════════════════════════════════════════
   SHARED COMPONENTS
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
      <img src="/mockup.png" alt="" className="block w-full h-full" draggable={false} />
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
        <img src={src} alt={alt} className="block w-full h-full object-cover object-top" draggable={false} />
      </div>
    </div>
  );
}

function Tablet({
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
      style={{
        aspectRatio: "1728 / 2448",
        ...style,
      }}
    >
      {/* Device shell */}
      <div
        style={{
          width: "100%",
          height: "100%",
          background: "#1C1C1E",
          borderRadius: "3.2%",
          padding: "1.7%",
          boxShadow: "0 12px 60px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.06)",
          boxSizing: "border-box",
        }}
      >
        {/* Camera dot */}
        <div
          style={{
            position: "absolute",
            top: "0.6%",
            left: "50%",
            transform: "translateX(-50%)",
            width: "0.5%",
            aspectRatio: "1 / 1",
            borderRadius: "50%",
            background: "#2a2a2e",
            zIndex: 2,
          }}
        />
        {/* Screen */}
        <div
          style={{
            width: "100%",
            height: "100%",
            borderRadius: "2%",
            overflow: "hidden",
          }}
        >
          <img
            src={src}
            alt={alt}
            style={{
              display: "block",
              width: "100%",
              height: "100%",
              objectFit: "cover",
              objectPosition: "top",
            }}
            draggable={false}
          />
        </div>
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

function CaptionBlock({
  label,
  headline,
  align = "center",
  light = false,
  canvasW,
}: {
  label: string;
  headline: React.ReactNode;
  align?: "center" | "left" | "right";
  light?: boolean;
  canvasW: number;
}) {
  const labelColor = light ? "rgba(28,120,245,0.9)" : "rgba(48,194,163,0.95)";
  const headlineColor = light ? "#0A1929" : "#FFFFFF";
  return (
    <div style={{ textAlign: align }}>
      <div
        style={{
          fontSize: canvasW * 0.028,
          fontWeight: 600,
          color: labelColor,
          letterSpacing: "0.06em",
          textTransform: "uppercase",
          marginBottom: canvasW * 0.015,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: canvasW * 0.09,
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

/* ═══════════════════════════════════════════════════════
   SLIDE BACKGROUNDS
   ═══════════════════════════════════════════════════════ */

function DarkOceanBg({
  children,
  blobs,
  w = W,
  h = H,
}: {
  children: React.ReactNode;
  blobs?: React.ReactNode;
  w?: number;
  h?: number;
}) {
  return (
    <div
      style={{
        width: w,
        height: h,
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

function LightBg({
  children,
  blobs,
  w = W,
  h = H,
}: {
  children: React.ReactNode;
  blobs?: React.ReactNode;
  w?: number;
  h?: number;
}) {
  return (
    <div
      style={{
        width: w,
        height: h,
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
   iPHONE SLIDES
   ═══════════════════════════════════════════════════════ */

function Slide1() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.lagoon} size={600} x={-200} y={200} blur={160} opacity={0.3} />
        <Blob color={BRAND.mint} size={500} x={700} y={1400} blur={140} opacity={0.2} />
        <Blob color={BRAND.lavender} size={400} x={900} y={400} blur={130} opacity={0.15} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", height: "100%", paddingTop: H * 0.06 }}>
        <div style={{ width: W * 0.22, aspectRatio: "1 / 1", borderRadius: W * 0.05, overflow: "hidden", boxShadow: "0 20px 60px rgba(28,120,245,0.3)", marginBottom: W * 0.035, flexShrink: 0 }}>
          <img src="/app-icon.png" alt="Sipli" style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }} />
        </div>
        <div style={{ marginTop: W * 0.01 }}>
          <CaptionBlock canvasW={W} label="Smart Hydration" headline={<>Stay Hydrated,<br />Effortlessly</>} />
        </div>
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone src="/screenshots/home-dark.png" alt="Sipli home screen" style={{ width: "82%", transform: "translateY(12%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide2() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.lavender} size={550} x={-150} y={600} blur={150} opacity={0.35} />
        <Blob color={BRAND.lagoon} size={450} x={600} y={1800} blur={130} opacity={0.25} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <CaptionBlock canvasW={W} label="AI-Powered" headline={<>A Coach That<br />Knows You</>} align="left" />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "flex-end", width: "100%" }}>
          <Phone src="/screenshots/home-dark-scrolled.png" alt="Hydration coach" style={{ width: "86%", transform: "translateX(8%) translateY(10%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide3() {
  return (
    <LightBg
      blobs={<>
        <Blob color={BRAND.lagoon} size={500} x={-100} y={800} blur={160} opacity={0.15} />
        <Blob color={BRAND.mint} size={400} x={800} y={1600} blur={140} opacity={0.12} />
        <Blob color={BRAND.lavender} size={350} x={400} y={300} blur={120} opacity={0.1} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <CaptionBlock canvasW={W} label="All Beverages" headline={<>Not Just<br />Water</>} light />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%", position: "relative" }}>
          <Phone src="/screenshots/log-intake-light.png" alt="Log intake light" style={{ width: "65%", position: "absolute", left: "-6%", bottom: "-6%", transform: "rotate(-4deg)", opacity: 0.6 }} />
          <Phone src="/screenshots/log-intake-dark.png" alt="Log intake" style={{ width: "80%", position: "absolute", right: "-2%", bottom: "-8%" }} />
        </div>
      </div>
    </LightBg>
  );
}

function Slide4() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.lagoon} size={600} x={500} y={300} blur={170} opacity={0.3} />
        <Blob color={BRAND.mint} size={450} x={-200} y={1500} blur={140} opacity={0.2} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <CaptionBlock canvasW={W} label="Weekly Insights" headline={<>See Your<br />Progress</>} align="right" />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "flex-start", width: "100%" }}>
          <Phone src="/screenshots/insights-dark.png" alt="Weekly insights" style={{ width: "86%", transform: "translateX(-6%) translateY(10%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide5() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.peach} size={500} x={-100} y={500} blur={150} opacity={0.2} />
        <Blob color={BRAND.sun} size={400} x={700} y={1200} blur={130} opacity={0.15} />
        <Blob color={BRAND.lagoon} size={350} x={200} y={2000} blur={120} opacity={0.2} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <CaptionBlock canvasW={W} label="Beverage Breakdown" headline={<>Every Sip,<br />Visualized</>} />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone src="/screenshots/insights-dark-scrolled.png" alt="Beverage breakdown" style={{ width: "82%", transform: "translateY(12%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide6() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.mint} size={550} x={600} y={600} blur={160} opacity={0.25} />
        <Blob color={BRAND.lagoon} size={400} x={-100} y={1800} blur={130} opacity={0.2} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, paddingLeft: W * 0.08, paddingRight: W * 0.08 }}>
        <CaptionBlock canvasW={W} label="Hydration Diary" headline={<>Look Back<br />Any Day</>} align="left" />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Phone src="/screenshots/diary-dark.png" alt="Hydration diary" style={{ width: "82%", transform: "translateY(12%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide7() {
  return (
    <DarkOceanBg
      blobs={<>
        <Blob color={BRAND.lagoon} size={600} x={100} y={400} blur={170} opacity={0.25} />
        <Blob color={BRAND.lavender} size={450} x={600} y={1600} blur={140} opacity={0.2} />
        <Blob color={BRAND.mint} size={300} x={-100} y={2200} blur={120} opacity={0.15} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: H * 0.1, alignItems: "center" }}>
        <CaptionBlock canvasW={W} label="Widgets" headline={<>One Glance<br />Away</>} />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%", position: "relative" }}>
          <Phone src="/screenshots/lockscreen.png" alt="Lock screen widgets" style={{ width: "62%", position: "absolute", left: "-4%", bottom: "-4%", transform: "rotate(-3deg)", opacity: 0.6 }} />
          <Phone src="/screenshots/widgets.png" alt="Home screen widgets" style={{ width: "78%", position: "absolute", right: "-2%", bottom: "-6%", transform: "rotate(2deg)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function Slide8() {
  const features = ["Weather-Adjusted Goals", "HealthKit Sync", "Dark & Light Mode", "Hydration Heatmap", "Activity Tracking", "Smart Reminders", "Daily Log", "Multiple Beverages"];
  const comingSoon = ["Apple Watch App", "Shortcuts"];
  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden", background: `linear-gradient(175deg, #080E1A 0%, ${BRAND.darkBg2} 50%, #060C18 100%)` }}>
      <Blob color={BRAND.lagoon} size={700} x={W / 2 - 350} y={H / 2 - 350} blur={200} opacity={0.12} />
      <Blob color={BRAND.lavender} size={400} x={-100} y={200} blur={150} opacity={0.1} />
      <Blob color={BRAND.mint} size={350} x={900} y={2200} blur={130} opacity={0.1} />
      <div style={{ position: "relative", zIndex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", padding: `0 ${W * 0.1}px`, gap: W * 0.06 }}>
        <div style={{ width: W * 0.24, aspectRatio: "1 / 1", borderRadius: W * 0.055, overflow: "hidden", boxShadow: "0 20px 80px rgba(28,120,245,0.25)", flexShrink: 0 }}>
          <img src="/app-icon.png" alt="Sipli" style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }} />
        </div>
        <CaptionBlock canvasW={W} label="Sipli" headline={<>And So<br />Much More</>} />
        <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: W * 0.022, maxWidth: W * 0.85 }}>
          {features.map((f) => (
            <div key={f} style={{ padding: `${W * 0.018}px ${W * 0.035}px`, borderRadius: W * 0.06, background: "rgba(255,255,255,0.08)", border: "1px solid rgba(255,255,255,0.12)", color: "rgba(255,255,255,0.85)", fontSize: W * 0.03, fontWeight: 500, whiteSpace: "nowrap" }}>{f}</div>
          ))}
        </div>
        <div style={{ textAlign: "center" }}>
          <div style={{ fontSize: W * 0.024, fontWeight: 600, color: "rgba(255,255,255,0.4)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: W * 0.02 }}>Coming Soon</div>
          <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: W * 0.022 }}>
            {comingSoon.map((f) => (
              <div key={f} style={{ padding: `${W * 0.018}px ${W * 0.035}px`, borderRadius: W * 0.06, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.35)", fontSize: W * 0.03, fontWeight: 500, whiteSpace: "nowrap" }}>{f}</div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   iPAD SLIDES
   ═══════════════════════════════════════════════════════ */

function IPadSlide1() {
  return (
    <DarkOceanBg w={IW} h={IH}
      blobs={<>
        <Blob color={BRAND.lagoon} size={800} x={-200} y={200} blur={200} opacity={0.3} />
        <Blob color={BRAND.mint} size={600} x={1200} y={1600} blur={180} opacity={0.2} />
        <Blob color={BRAND.lavender} size={500} x={1400} y={400} blur={160} opacity={0.15} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", height: "100%", paddingTop: IH * 0.06 }}>
        <div style={{ width: IW * 0.16, aspectRatio: "1 / 1", borderRadius: IW * 0.038, overflow: "hidden", boxShadow: "0 24px 80px rgba(28,120,245,0.3)", marginBottom: IW * 0.03, flexShrink: 0 }}>
          <img src="/app-icon.png" alt="Sipli" style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }} />
        </div>
        <div style={{ marginTop: IW * 0.01 }}>
          <CaptionBlock canvasW={IW} label="Smart Hydration" headline={<>Stay Hydrated,<br />Effortlessly</>} />
        </div>
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Tablet src="/screenshots/ipad-home-dark.png" alt="Sipli iPad home" style={{ width: "78%", transform: "translateY(8%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function IPadSlide2() {
  return (
    <DarkOceanBg w={IW} h={IH}
      blobs={<>
        <Blob color={BRAND.lagoon} size={700} x={800} y={300} blur={200} opacity={0.3} />
        <Blob color={BRAND.mint} size={550} x={-200} y={1600} blur={170} opacity={0.2} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: IH * 0.08, paddingLeft: IW * 0.07, paddingRight: IW * 0.07 }}>
        <CaptionBlock canvasW={IW} label="Weekly Insights" headline={<>See Your<br />Progress</>} align="right" />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "flex-start", width: "100%" }}>
          <Tablet src="/screenshots/ipad-insights-dark.png" alt="iPad insights" style={{ width: "82%", transform: "translateX(-4%) translateY(6%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function IPadSlide3() {
  return (
    <DarkOceanBg w={IW} h={IH}
      blobs={<>
        <Blob color={BRAND.mint} size={650} x={800} y={600} blur={180} opacity={0.25} />
        <Blob color={BRAND.lagoon} size={500} x={-100} y={1800} blur={160} opacity={0.2} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: IH * 0.08, paddingLeft: IW * 0.07, paddingRight: IW * 0.07 }}>
        <CaptionBlock canvasW={IW} label="Hydration Diary" headline={<>Look Back<br />Any Day</>} align="left" />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Tablet src="/screenshots/ipad-diary-dark.png" alt="iPad diary" style={{ width: "78%", transform: "translateY(8%)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

function IPadSlide4() {
  return (
    <LightBg w={IW} h={IH}
      blobs={<>
        <Blob color={BRAND.lagoon} size={600} x={-100} y={800} blur={180} opacity={0.15} />
        <Blob color={BRAND.mint} size={500} x={1200} y={1600} blur={160} opacity={0.12} />
        <Blob color={BRAND.lavender} size={400} x={600} y={300} blur={140} opacity={0.1} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: IH * 0.08, alignItems: "center" }}>
        <CaptionBlock canvasW={IW} label="All Beverages" headline={<>Not Just<br />Water</>} light />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%" }}>
          <Tablet src="/screenshots/ipad-log-intake-dark.png" alt="iPad log intake" style={{ width: "78%", transform: "translateY(8%)" }} />
        </div>
      </div>
    </LightBg>
  );
}

function IPadSlide5() {
  return (
    <DarkOceanBg w={IW} h={IH}
      blobs={<>
        <Blob color={BRAND.lagoon} size={700} x={200} y={400} blur={200} opacity={0.25} />
        <Blob color={BRAND.lavender} size={550} x={1000} y={1600} blur={170} opacity={0.2} />
        <Blob color={BRAND.mint} size={400} x={-100} y={2200} blur={150} opacity={0.15} />
      </>}
    >
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: IH * 0.08, alignItems: "center" }}>
        <CaptionBlock canvasW={IW} label="Widgets" headline={<>One Glance<br />Away</>} />
        <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "center", width: "100%", position: "relative" }}>
          <Tablet src="/screenshots/ipad-lockscreen.png" alt="iPad lock screen" style={{ width: "58%", position: "absolute", left: "-2%", bottom: "-3%", transform: "rotate(-3deg)", opacity: 0.6 }} />
          <Tablet src="/screenshots/ipad-widgets.png" alt="iPad widgets" style={{ width: "72%", position: "absolute", right: "-1%", bottom: "-4%", transform: "rotate(2deg)" }} />
        </div>
      </div>
    </DarkOceanBg>
  );
}

/* ═══════════════════════════════════════════════════════
   SCREENSHOT REGISTRIES
   ═══════════════════════════════════════════════════════ */

type ScreenshotEntry = { name: string; component: React.FC };

const IPHONE_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "hero", component: Slide1 },
  { name: "coach", component: Slide2 },
  { name: "beverages", component: Slide3 },
  { name: "insights", component: Slide4 },
  { name: "breakdown", component: Slide5 },
  { name: "diary", component: Slide6 },
  { name: "widgets", component: Slide7 },
  { name: "more", component: Slide8 },
];

const IPAD_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "ipad-hero", component: IPadSlide1 },
  { name: "ipad-insights", component: IPadSlide2 },
  { name: "ipad-diary", component: IPadSlide3 },
  { name: "ipad-beverages", component: IPadSlide4 },
  { name: "ipad-widgets", component: IPadSlide5 },
];

/* ═══════════════════════════════════════════════════════
   PREVIEW COMPONENT
   ═══════════════════════════════════════════════════════ */

function ScreenshotPreview({
  entry,
  index,
  exportRef,
  canvasW,
  canvasH,
  sizes,
  prefix: prefixLabel,
}: {
  entry: ScreenshotEntry;
  index: number;
  exportRef: React.RefObject<HTMLDivElement | null>;
  canvasW: number;
  canvasH: number;
  sizes: readonly { label: string; w: number; h: number }[];
  prefix: string;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);
  const [exporting, setExporting] = useState(false);
  const Component = entry.component;

  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => {
      setScale(e.contentRect.width / canvasW);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [canvasW]);

  const handleExport = useCallback(async () => {
    const el = exportRef.current;
    if (!el || exporting) return;
    setExporting(true);
    try {
      for (const size of sizes) {
        await captureAndDownload(el, `${prefixLabel}-${entry.name}`, canvasW, canvasH, size.w, size.h);
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch (err) {
      console.error(`Export failed for ${entry.name}:`, err);
      alert(`Export failed for "${entry.name}". Check console for details.`);
    } finally {
      setExporting(false);
    }
  }, [entry.name, exporting, exportRef, canvasW, canvasH, sizes, prefixLabel]);

  return (
    <div>
      <div
        ref={wrapRef}
        onClick={handleExport}
        style={{ width: "100%", aspectRatio: `${canvasW}/${canvasH}`, overflow: "hidden", borderRadius: 12, cursor: exporting ? "wait" : "pointer", border: "1px solid rgba(255,255,255,0.1)", position: "relative" }}
      >
        <div style={{ width: canvasW, height: canvasH, transform: `scale(${scale})`, transformOrigin: "top left" }}>
          <Component />
        </div>
      </div>
      <div style={{ textAlign: "center", marginTop: 8, fontSize: 13, color: "rgba(255,255,255,0.6)", fontWeight: 500 }}>
        {String(index + 1).padStart(2, "0")} — {entry.name}
        {exporting && " (exporting...)"}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   PAGE
   ═══════════════════════════════════════════════════════ */

function DeviceSection({
  title,
  screenshots,
  sizes,
  canvasW,
  canvasH,
  filenamePrefix,
}: {
  title: string;
  screenshots: ScreenshotEntry[];
  sizes: readonly { label: string; w: number; h: number }[];
  canvasW: number;
  canvasH: number;
  filenamePrefix: string;
}) {
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [exportingAll, setExportingAll] = useState(false);
  const [selectedSize, setSelectedSize] = useState(0);

  const exportAll = useCallback(async () => {
    if (exportingAll) return;
    setExportingAll(true);
    const size = sizes[selectedSize];
    try {
      for (let i = 0; i < screenshots.length; i++) {
        const el = exportRefs.current[i];
        if (!el) continue;
        const prefix = String(i + 1).padStart(2, "0");
        await captureAndDownload(el, `${prefix}-${screenshots[i].name}`, canvasW, canvasH, size.w, size.h);
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch (err) {
      console.error("Export all failed:", err);
      alert("Export failed. Check console for details.");
    } finally {
      setExportingAll(false);
    }
  }, [exportingAll, selectedSize, screenshots, sizes, canvasW, canvasH]);

  return (
    <section style={{ marginBottom: 60 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 24, flexWrap: "wrap", gap: 16 }}>
        <h2 style={{ color: "white", fontSize: 20, fontWeight: 700, margin: 0 }}>{title}</h2>
        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <select
            value={selectedSize}
            onChange={(e) => setSelectedSize(Number(e.target.value))}
            style={{ background: "rgba(255,255,255,0.1)", color: "white", border: "1px solid rgba(255,255,255,0.2)", borderRadius: 8, padding: "8px 12px", fontSize: 14 }}
          >
            {sizes.map((s, i) => (
              <option key={i} value={i}>{s.label} ({s.w}x{s.h})</option>
            ))}
          </select>
          <button
            onClick={exportAll}
            disabled={exportingAll}
            style={{ background: exportingAll ? "rgba(28,120,245,0.5)" : BRAND.lagoon, color: "white", border: "none", borderRadius: 8, padding: "10px 20px", fontSize: 14, fontWeight: 600, cursor: exportingAll ? "wait" : "pointer" }}
          >
            {exportingAll ? "Exporting..." : `Export All (${sizes[selectedSize].label})`}
          </button>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))", gap: 24 }}>
        {screenshots.map((entry, i) => (
          <ScreenshotPreview
            key={entry.name}
            entry={entry}
            index={i}
            exportRef={{ current: exportRefs.current[i] ?? null }}
            canvasW={canvasW}
            canvasH={canvasH}
            sizes={sizes}
            prefix={String(i + 1).padStart(2, "0")}
          />
        ))}
      </div>

      {screenshots.map((entry, i) => {
        const Component = entry.component;
        return (
          <div
            key={`export-${entry.name}`}
            ref={(el) => { exportRefs.current[i] = el; }}
            style={{ position: "absolute", left: "-9999px", top: 0, width: canvasW, height: canvasH, fontFamily: "Inter, sans-serif" }}
          >
            <Component />
          </div>
        );
      })}
    </section>
  );
}

export default function ScreenshotsPage() {
  return (
    <div style={{ minHeight: "100vh", background: "#0A0A0A", padding: "40px 32px" }}>
      <h1 style={{ color: "white", fontSize: 28, fontWeight: 700, margin: "0 0 40px 0" }}>
        Sipli — App Store Screenshots
      </h1>

      <DeviceSection
        title="iPhone"
        screenshots={IPHONE_SCREENSHOTS}
        sizes={IPHONE_SIZES}
        canvasW={W}
        canvasH={H}
        filenamePrefix="iphone"
      />

      <DeviceSection
        title="iPad"
        screenshots={IPAD_SCREENSHOTS}
        sizes={IPAD_SIZES}
        canvasW={IW}
        canvasH={IH}
        filenamePrefix="ipad"
      />

      <p style={{ textAlign: "center", color: "rgba(255,255,255,0.3)", marginTop: 40, fontSize: 13 }}>
        Click any screenshot to export all sizes for that device. Use &ldquo;Export All&rdquo; for a single size.
      </p>
    </div>
  );
}

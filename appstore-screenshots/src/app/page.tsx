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

/* ─── Apple Watch ─── */
const WW = 396;
const WH = 484;

const WATCH_SIZES = [
  { label: '45mm', w: 396, h: 484 },
  { label: '44mm', w: 368, h: 448 },
  { label: '41mm', w: 352, h: 430 },
  { label: '40mm', w: 324, h: 394 },
  { label: '49mm Ultra', w: 410, h: 502 },
  { label: '42mm', w: 312, h: 390 },
  { label: '38mm', w: 272, h: 340 },
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
  // Earth Day greens (mirrors EarthDayBannerCard.swift)
  leafBright: "#38A06B",   // rgb(0.22, 0.62, 0.42)
  leafDeep: "#0D734C",     // rgb(0.05, 0.45, 0.30)
  leafDarker: "#0A4D38",   // rgb(0.04, 0.30, 0.22)
  leafButtonText: "#0D5438", // rgb(0.05, 0.33, 0.22)
  mintBgLight: "#E0F5E6",   // rgb(0.88, 0.96, 0.90)
  mintBgDeep: "#B8E6CC",    // rgb(0.72, 0.90, 0.80)
  forestNight: "#05261B",
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
   EARTH DAY BACKGROUNDS & UI ELEMENTS
   ═══════════════════════════════════════════════════════ */

function EarthDarkBg({
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
        background: `linear-gradient(170deg, ${BRAND.leafDeep} 0%, ${BRAND.leafDarker} 45%, ${BRAND.forestNight} 100%)`,
      }}
    >
      {blobs}
      <div style={{ position: "relative", zIndex: 1, width: "100%", height: "100%" }}>
        {children}
      </div>
    </div>
  );
}

function EarthLightBg({
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
        background: `linear-gradient(170deg, #F2FBF4 0%, ${BRAND.mintBgLight} 45%, ${BRAND.mintBgDeep} 100%)`,
      }}
    >
      {blobs}
      <div style={{ position: "relative", zIndex: 1, width: "100%", height: "100%" }}>
        {children}
      </div>
    </div>
  );
}

/**
 * Recreated Earth Week banner — mirrors EarthDayBannerCard.swift.
 * `scale` multiplies sizes so the banner can be used both in-app and as an
 * oversized floating callout.
 */
function EarthWeekBanner({ scale = 1 }: { scale?: number }) {
  const pad = 36 * scale;
  const radius = 48 * scale;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: 28 * scale,
        padding: pad,
        borderRadius: radius,
        background: `linear-gradient(135deg, ${BRAND.leafBright} 0%, ${BRAND.leafDeep} 100%)`,
        border: `${2 * scale}px solid rgba(255,255,255,0.18)`,
        boxShadow: `0 ${20 * scale}px ${60 * scale}px rgba(5,45,30,0.45)`,
        width: "100%",
        boxSizing: "border-box",
      }}
    >
      <div
        style={{
          flexShrink: 0,
          width: 88 * scale,
          height: 88 * scale,
          borderRadius: "50%",
          background: "rgba(255,255,255,0.22)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 44 * scale,
          color: "#FFFFFF",
        }}
      >
        🌿
      </div>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 14 * scale }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14 * scale }}>
          <span
            style={{
              fontSize: 36 * scale,
              fontWeight: 800,
              color: "#FFFFFF",
              letterSpacing: "-0.01em",
            }}
          >
            Earth Week
          </span>
          <span
            style={{
              fontSize: 20 * scale,
              fontWeight: 600,
              color: "rgba(255,255,255,0.88)",
              padding: `${6 * scale}px ${16 * scale}px`,
              borderRadius: 999,
              background: "rgba(255,255,255,0.18)",
            }}
          >
            Apr 20-26
          </span>
        </div>
        <div
          style={{
            fontSize: 26 * scale,
            fontWeight: 500,
            color: "rgba(255,255,255,0.95)",
            lineHeight: 1.28,
          }}
        >
          Every refill is one less plastic bottle.
        </div>
        <div
          style={{
            display: "inline-flex",
            alignSelf: "flex-start",
            alignItems: "center",
            gap: 10 * scale,
            marginTop: 6 * scale,
            padding: `${14 * scale}px ${28 * scale}px`,
            borderRadius: 999,
            background: "rgba(255,255,255,0.96)",
            color: BRAND.leafButtonText,
            fontSize: 24 * scale,
            fontWeight: 700,
          }}
        >
          Take the Refill Pledge <span>→</span>
        </div>
      </div>
    </div>
  );
}

/** Recreated Refill Pledge card — mirrors EarthDayPledgeView.swift's pledgeCard. */
function RefillPledgeCard({ scale = 1, name = "Anoop" }: { scale?: number; name?: string }) {
  return (
    <div
      style={{
        width: 760 * scale,
        padding: 56 * scale,
        borderRadius: 56 * scale,
        background: `linear-gradient(135deg, ${BRAND.leafBright} 0%, ${BRAND.leafDeep} 55%, ${BRAND.leafDarker} 100%)`,
        border: `${2 * scale}px solid rgba(255,255,255,0.18)`,
        boxShadow: `0 ${32 * scale}px ${80 * scale}px rgba(0,30,20,0.45)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 32 * scale,
        boxSizing: "border-box",
      }}
    >
      <div
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 12 * scale,
          padding: `${12 * scale}px ${24 * scale}px`,
          borderRadius: 999,
          background: "rgba(255,255,255,0.18)",
          color: "#FFFFFF",
          fontSize: 22 * scale,
          fontWeight: 800,
          letterSpacing: "0.18em",
        }}
      >
        🌿 EARTH WEEK 2026
      </div>

      <div
        style={{
          fontSize: 62 * scale,
          fontWeight: 800,
          color: "#FFFFFF",
          lineHeight: 1.05,
          textAlign: "center",
          letterSpacing: "-0.02em",
        }}
      >
        I pledge to refill,<br />not rebuy,<br />this Earth Week.
      </div>

      <div
        style={{
          fontSize: 30 * scale,
          fontWeight: 600,
          color: "rgba(255,255,255,0.92)",
        }}
      >
        — {name}
      </div>

      <div
        style={{
          textAlign: "center",
          color: "rgba(255,255,255,0.88)",
          fontSize: 24 * scale,
          fontWeight: 500,
          lineHeight: 1.3,
        }}
      >
        Every sip tracked<br />is one less plastic bottle.
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10 * scale, marginTop: 8 * scale }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14 * scale }}>
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{
              width: 56 * scale,
              height: 56 * scale,
              borderRadius: 12 * scale,
              display: "block",
            }}
          />
          <span style={{ fontSize: 28 * scale, fontWeight: 800, color: "#FFFFFF" }}>Sipli</span>
        </div>
        <div
          style={{
            fontSize: 20 * scale,
            fontWeight: 600,
            color: "rgba(255,255,255,0.78)",
            letterSpacing: "0.08em",
            textTransform: "uppercase",
          }}
        >
          Available on the App Store
        </div>
      </div>
    </div>
  );
}

/** Recreated Earth Week insights tile — mirrors InsightsView.swift's earthWeekSection. */
function EarthWeekInsightCard({ scale = 1 }: { scale?: number }) {
  return (
    <div
      style={{
        width: 720 * scale,
        padding: 40 * scale,
        borderRadius: 40 * scale,
        background: "#FFFFFF",
        boxShadow: `0 ${24 * scale}px ${60 * scale}px rgba(5,45,30,0.3)`,
        display: "flex",
        flexDirection: "column",
        gap: 24 * scale,
        boxSizing: "border-box",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 14 * scale }}>
        <div
          style={{
            width: 52 * scale,
            height: 52 * scale,
            borderRadius: "50%",
            background: "rgba(56,160,107,0.18)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 28 * scale,
          }}
        >
          🌿
        </div>
        <div style={{ fontSize: 28 * scale, fontWeight: 800, color: "#0A1929" }}>
          Earth Week
        </div>
      </div>

      <div style={{ display: "flex", alignItems: "flex-start", gap: 20 * scale }}>
        <div
          style={{
            fontSize: 30 * scale,
            fontWeight: 700,
            color: "#0A1929",
            lineHeight: 1.25,
          }}
        >
          You&apos;ve sipped <span style={{ color: BRAND.leafDeep }}>37 times</span> this Earth Week.
        </div>
      </div>

      <div style={{ fontSize: 22 * scale, fontWeight: 500, color: "rgba(10,25,41,0.55)", lineHeight: 1.35 }}>
        Every refill is one less plastic bottle.
      </div>

      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10 * scale,
          marginTop: 4 * scale,
          padding: `${16 * scale}px ${22 * scale}px`,
          background: "rgba(28,120,245,0.08)",
          borderRadius: 18 * scale,
        }}
      >
        <span style={{ color: BRAND.lagoon, fontSize: 24 * scale }}>💧</span>
        <span style={{ fontSize: 22 * scale, fontWeight: 600, color: "rgba(10,25,41,0.75)" }}>
          Total: 9.2 L
        </span>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════
   EARTH DAY SLIDES
   ═══════════════════════════════════════════════════════ */

function EarthSlide1() {
  // Hero — app icon + "Every Sip, Less Plastic." + phone home
  return (
    <EarthDarkBg
      blobs={<>
        <Blob color={BRAND.leafBright} size={700} x={-220} y={300} blur={180} opacity={0.35} />
        <Blob color={BRAND.mint} size={560} x={780} y={1500} blur={160} opacity={0.25} />
        <Blob color={BRAND.leafBright} size={420} x={920} y={380} blur={140} opacity={0.2} />
      </>}
    >
      <div
        style={{
          position: "absolute",
          top: W * 0.05,
          left: W * 0.06,
          fontSize: W * 0.1,
          opacity: 0.16,
          pointerEvents: "none",
        }}
      >
        🌿
      </div>
      <div
        style={{
          position: "absolute",
          top: H * 0.22,
          right: W * 0.04,
          fontSize: W * 0.08,
          opacity: 0.14,
          pointerEvents: "none",
          transform: "rotate(18deg)",
        }}
      >
        🍃
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          height: "100%",
          paddingTop: H * 0.06,
        }}
      >
        <div
          style={{
            width: W * 0.22,
            aspectRatio: "1 / 1",
            borderRadius: W * 0.05,
            overflow: "hidden",
            boxShadow: "0 20px 60px rgba(5,45,30,0.4)",
            marginBottom: W * 0.035,
            flexShrink: 0,
          }}
        >
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }}
          />
        </div>
        <div style={{ marginTop: W * 0.01 }}>
          <div style={{ textAlign: "center" }}>
            <div
              style={{
                fontSize: W * 0.028,
                fontWeight: 600,
                color: "rgba(184,230,204,0.95)",
                letterSpacing: "0.1em",
                textTransform: "uppercase",
                marginBottom: W * 0.015,
              }}
            >
              🌿 Earth Week 2026
            </div>
            <div
              style={{
                fontSize: W * 0.1,
                fontWeight: 700,
                lineHeight: 0.95,
                color: "#FFFFFF",
                letterSpacing: "-0.02em",
              }}
            >
              Every Sip,<br />Less Plastic.
            </div>
          </div>
        </div>
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "center",
            width: "100%",
          }}
        >
          <Phone
            src="/screenshots/home-dark.png"
            alt="Sipli home screen"
            style={{ width: "82%", transform: "translateY(12%)" }}
          />
        </div>
      </div>
    </EarthDarkBg>
  );
}

function EarthSlide2() {
  // Earth Week banner — phone home + oversized floating banner + headline
  return (
    <EarthDarkBg
      blobs={<>
        <Blob color={BRAND.leafBright} size={620} x={-160} y={500} blur={170} opacity={0.35} />
        <Blob color={BRAND.mint} size={480} x={700} y={1800} blur={150} opacity={0.28} />
      </>}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          height: "100%",
          paddingTop: H * 0.08,
          paddingLeft: W * 0.08,
          paddingRight: W * 0.08,
        }}
      >
        <CaptionBlock
          canvasW={W}
          label="Earth Week is Here"
          headline={<>Refill.<br />Don&apos;t Rebuy.</>}
          align="left"
        />
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "100%",
            position: "relative",
          }}
        >
          <Phone
            src="/screenshots/home-dark.png"
            alt="Sipli home"
            style={{
              width: "70%",
              position: "absolute",
              right: "-6%",
              bottom: "-10%",
            }}
          />
          <div
            style={{
              position: "absolute",
              left: "-2%",
              top: "12%",
              width: "78%",
              transform: "rotate(-3deg)",
            }}
          >
            <EarthWeekBanner scale={1.4} />
          </div>
        </div>
      </div>
    </EarthDarkBg>
  );
}

function EarthSlide3() {
  // Refill Pledge — big floating pledge card as the hero element
  return (
    <EarthLightBg
      blobs={<>
        <Blob color={BRAND.leafBright} size={620} x={-140} y={400} blur={180} opacity={0.22} />
        <Blob color={BRAND.mint} size={520} x={820} y={1500} blur={160} opacity={0.2} />
        <Blob color={BRAND.leafDeep} size={380} x={380} y={2100} blur={140} opacity={0.15} />
      </>}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          height: "100%",
          paddingTop: H * 0.08,
          alignItems: "center",
        }}
      >
        <CaptionBlock
          canvasW={W}
          label="Refill Pledge"
          headline={<>Make It<br />Official.</>}
          light
        />
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "100%",
            marginTop: H * 0.02,
          }}
        >
          <div style={{ transform: "rotate(-2deg)" }}>
            <RefillPledgeCard scale={1.55} name="Anoop" />
          </div>
        </div>
      </div>
    </EarthLightBg>
  );
}

function EarthSlide4() {
  // Insights — phone + floating Earth Week insight tile
  return (
    <EarthDarkBg
      blobs={<>
        <Blob color={BRAND.leafBright} size={660} x={700} y={400} blur={180} opacity={0.3} />
        <Blob color={BRAND.mint} size={520} x={-180} y={1700} blur={160} opacity={0.25} />
      </>}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          height: "100%",
          paddingTop: H * 0.08,
          paddingLeft: W * 0.08,
          paddingRight: W * 0.08,
        }}
      >
        <CaptionBlock
          canvasW={W}
          label="Weekly Insights"
          headline={<>Every Refill,<br />Counted.</>}
          align="right"
        />
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "100%",
            position: "relative",
          }}
        >
          <Phone
            src="/screenshots/insights-dark.png"
            alt="Weekly insights"
            style={{
              width: "72%",
              position: "absolute",
              left: "-8%",
              bottom: "-10%",
            }}
          />
          <div
            style={{
              position: "absolute",
              right: "-4%",
              top: "20%",
              width: "72%",
              transform: "rotate(3deg)",
            }}
          >
            <EarthWeekInsightCard scale={1.5} />
          </div>
        </div>
      </div>
    </EarthDarkBg>
  );
}

function EarthSlide5() {
  // Facts — dark green bg with fact pills (Why Reusable Bottles)
  const facts = [
    "Tap water works",
    "A habit beats a one-off",
    "Single-use plastic lingers",
    "Small, honest wins",
    "Hydration is personal",
  ];
  return (
    <div
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        background: `linear-gradient(175deg, ${BRAND.leafDarker} 0%, ${BRAND.forestNight} 55%, #021A12 100%)`,
      }}
    >
      <Blob color={BRAND.leafBright} size={720} x={W / 2 - 360} y={H / 2 - 360} blur={220} opacity={0.14} />
      <Blob color={BRAND.mint} size={460} x={-140} y={240} blur={160} opacity={0.12} />
      <Blob color={BRAND.leafBright} size={400} x={960} y={2200} blur={150} opacity={0.13} />

      <div
        style={{
          position: "absolute",
          top: H * 0.05,
          left: W * 0.06,
          fontSize: W * 0.09,
          opacity: 0.1,
          pointerEvents: "none",
        }}
      >
        🌿
      </div>
      <div
        style={{
          position: "absolute",
          top: H * 0.6,
          right: W * 0.05,
          fontSize: W * 0.08,
          opacity: 0.1,
          pointerEvents: "none",
          transform: "rotate(22deg)",
        }}
      >
        🍃
      </div>

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
            width: W * 0.22,
            aspectRatio: "1 / 1",
            borderRadius: W * 0.05,
            overflow: "hidden",
            boxShadow: "0 20px 80px rgba(5,45,30,0.5)",
            flexShrink: 0,
          }}
        >
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }}
          />
        </div>
        <CaptionBlock
          canvasW={W}
          label="Why Reusable Bottles"
          headline={<>Small Wins,<br />Big Impact.</>}
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
          {facts.map((f) => (
            <div
              key={f}
              style={{
                padding: `${W * 0.02}px ${W * 0.038}px`,
                borderRadius: W * 0.06,
                background: "rgba(56,160,107,0.18)",
                border: "1px solid rgba(184,230,204,0.28)",
                color: "rgba(255,255,255,0.92)",
                fontSize: W * 0.032,
                fontWeight: 600,
                whiteSpace: "nowrap",
              }}
            >
              🌿 {f}
            </div>
          ))}
        </div>
        <div
          style={{
            textAlign: "center",
            marginTop: W * 0.02,
            fontSize: W * 0.028,
            fontWeight: 500,
            color: "rgba(184,230,204,0.78)",
            maxWidth: W * 0.75,
            lineHeight: 1.4,
          }}
        >
          Sipli just helps you notice each sip —<br />
          and noticing is what makes a habit stick.
        </div>
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

/**
 * Sprint 5a — candidate hero replacing the generic "Stay Hydrated, Effortlessly"
 * headline with keyword-forward copy that matches the new ASO strategy.
 *
 * Copy-only change vs. Slide1 — identical composition (same bg, same blobs,
 * same phone mockup) so an A/B test isolates the caption as the only variable.
 *
 * Rendered in the "Proposed (not live)" preview section at the bottom of the
 * page. NOT wired into IPHONE_SCREENSHOTS — promoting to production happens
 * only after PPO test data confirms it converts at least as well as Slide1.
 */
function Slide1HeroV2() {
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
          <CaptionBlock canvasW={W} label="Water Tracker · Drink Reminder" headline={<>Hydration,<br />on autopilot.</>} />
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
   APPLE WATCH COMPONENTS & SLIDES
   ═══════════════════════════════════════════════════════ */

function WatchProgressRing({
  progress,
  size = 160,
  id = "wr",
}: {
  progress: number;
  size?: number;
  id?: string;
}) {
  const strokeW = size * 0.075;
  const r = size / 2 - strokeW;
  const circ = 2 * Math.PI * r;
  const dash = circ * Math.min(progress, 1);
  return (
    <svg width={size} height={size} style={{ display: "block" }}>
      <defs>
        <linearGradient id={`${id}Grad`} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor={BRAND.lagoon} />
          <stop offset="100%" stopColor={BRAND.mint} />
        </linearGradient>
      </defs>
      <circle
        cx={size / 2} cy={size / 2} r={r}
        fill="none"
        stroke="rgba(255,255,255,0.08)"
        strokeWidth={strokeW}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      {progress > 0 && (
        <circle
          cx={size / 2} cy={size / 2} r={r}
          fill="none"
          stroke={`url(#${id}Grad)`}
          strokeWidth={strokeW}
          strokeLinecap="round"
          strokeDasharray={`${dash} ${circ - dash}`}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      )}
    </svg>
  );
}

function WatchDarkBg({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ width: WW, height: WH, position: "relative", overflow: "hidden", background: "#000000" }}>
      {children}
    </div>
  );
}

/* ─── Watch Slide 1: Dashboard ─── */
function WatchSlide1() {
  const ringSize = WW * 0.54;
  return (
    <WatchDarkBg>
      <div style={{
        position: "absolute", top: WH * 0.08, left: "50%",
        transform: "translateX(-50%)",
        width: ringSize * 1.3, height: ringSize * 1.3, borderRadius: "50%",
        background: "radial-gradient(circle, rgba(28,120,245,0.2) 0%, transparent 68%)",
        pointerEvents: "none",
      }} />
      <div style={{
        display: "flex", flexDirection: "column", alignItems: "center",
        height: "100%", paddingTop: WH * 0.05, paddingBottom: WH * 0.04,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: WW * 0.025, marginBottom: WH * 0.02 }}>
          <span style={{ fontSize: WW * 0.055, lineHeight: 1 }}>💧</span>
          <span style={{ fontSize: WW * 0.052, fontWeight: 700, color: "rgba(255,255,255,0.7)", letterSpacing: "0.06em", textTransform: "uppercase" }}>Sipli</span>
        </div>
        <div style={{ position: "relative", width: ringSize, height: ringSize, flexShrink: 0 }}>
          <WatchProgressRing progress={0.72} size={ringSize} id="ws1" />
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
            <div style={{ fontSize: WW * 0.15, fontWeight: 700, color: "#FFFFFF", lineHeight: 1, letterSpacing: "-0.03em" }}>1.8</div>
            <div style={{ fontSize: WW * 0.065, fontWeight: 600, color: BRAND.mint, lineHeight: 1 }}>L</div>
            <div style={{ fontSize: WW * 0.038, fontWeight: 500, color: "rgba(255,255,255,0.42)", marginTop: WH * 0.006 }}>of 2.5 L</div>
          </div>
        </div>
        <div style={{ display: "flex", gap: WW * 0.1, marginTop: WH * 0.018 }}>
          {[{ label: "72%", sub: "Done" }, { label: "5", sub: "Entries" }].map(({ label, sub }) => (
            <div key={sub} style={{ textAlign: "center" }}>
              <div style={{ fontSize: WW * 0.062, fontWeight: 700, color: BRAND.lagoon }}>{label}</div>
              <div style={{ fontSize: WW * 0.034, color: "rgba(255,255,255,0.38)", marginTop: 2 }}>{sub}</div>
            </div>
          ))}
        </div>
        <div style={{ flex: 1, width: "100%", display: "flex", flexDirection: "column", gap: WH * 0.01, paddingLeft: WW * 0.06, paddingRight: WW * 0.06, marginTop: WH * 0.022, overflow: "hidden" }}>
          {[{ icon: "💧", label: "Water", time: "9:32 AM", amount: "300 mL" }, { icon: "☕", label: "Coffee", time: "11:15 AM", amount: "200 mL" }].map(({ icon, label, time, amount }) => (
            <div key={label} style={{ display: "flex", alignItems: "center", gap: WW * 0.03, background: "rgba(255,255,255,0.06)", borderRadius: WW * 0.038, padding: `${WH * 0.016}px ${WW * 0.04}px` }}>
              <span style={{ fontSize: WW * 0.062, lineHeight: 1 }}>{icon}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: WW * 0.047, fontWeight: 600, color: "#FFFFFF" }}>{label}</div>
                <div style={{ fontSize: WW * 0.034, color: "rgba(255,255,255,0.38)" }}>{time}</div>
              </div>
              <div style={{ fontSize: WW * 0.042, color: BRAND.lagoon, fontWeight: 600 }}>{amount}</div>
            </div>
          ))}
        </div>
        <div style={{ width: WW * 0.56, height: WH * 0.1, borderRadius: WW * 0.12, background: BRAND.lagoon, display: "flex", alignItems: "center", justifyContent: "center", gap: WW * 0.02, marginTop: WH * 0.018, flexShrink: 0, boxShadow: "0 4px 20px rgba(28,120,245,0.4)" }}>
          <span style={{ fontSize: WW * 0.07, color: "#FFFFFF", lineHeight: 1, marginTop: -2 }}>+</span>
          <span style={{ fontSize: WW * 0.048, fontWeight: 700, color: "#FFFFFF" }}>Add</span>
        </div>
      </div>
    </WatchDarkBg>
  );
}

/* ─── Watch Slide 2: Quick Add ─── */
function WatchSlide2() {
  return (
    <WatchDarkBg>
      <div style={{ position: "absolute", inset: 0, background: "radial-gradient(circle at 50% 42%, rgba(28,120,245,0.22) 0%, transparent 62%)", pointerEvents: "none" }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", height: "100%", paddingTop: WH * 0.06, paddingBottom: WH * 0.06 }}>
        <div style={{ width: WW * 0.22, height: WW * 0.22, borderRadius: "50%", background: "rgba(28,120,245,0.18)", border: "2px solid rgba(28,120,245,0.4)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: WW * 0.1, marginBottom: WH * 0.022, flexShrink: 0 }}>
          💧
        </div>
        <div style={{ fontSize: WW * 0.048, fontWeight: 600, color: "rgba(255,255,255,0.55)", letterSpacing: "0.06em", marginBottom: WH * 0.018 }}>WATER</div>
        <div style={{ display: "flex", alignItems: "center", gap: WW * 0.06, marginBottom: WH * 0.012 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: WH * 0.01, alignItems: "center" }}>
            <div style={{ color: "rgba(255,255,255,0.28)", fontSize: WW * 0.042, lineHeight: 1 }}>▲</div>
            <div style={{ color: "rgba(255,255,255,0.28)", fontSize: WW * 0.042, lineHeight: 1 }}>▼</div>
          </div>
          <div style={{ textAlign: "center" }}>
            <div style={{ fontSize: WW * 0.24, fontWeight: 700, color: "#FFFFFF", lineHeight: 0.88, letterSpacing: "-0.04em" }}>250</div>
            <div style={{ fontSize: WW * 0.065, fontWeight: 600, color: BRAND.lagoon, marginTop: WH * 0.01 }}>mL</div>
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: WW * 0.025, marginBottom: WH * 0.02 }}>
          <div style={{ width: WW * 0.024, height: WH * 0.022, borderRadius: WW * 0.018, background: "rgba(255,255,255,0.18)" }} />
          <span style={{ fontSize: WW * 0.034, color: "rgba(255,255,255,0.32)" }}>Scroll Digital Crown to adjust</span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ width: "80%", height: WH * 0.115, borderRadius: WW * 0.14, background: `linear-gradient(135deg, ${BRAND.lagoon} 0%, ${BRAND.mint} 100%)`, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 6px 24px rgba(28,120,245,0.45)", flexShrink: 0 }}>
          <span style={{ fontSize: WW * 0.062, fontWeight: 700, color: "#FFFFFF", letterSpacing: "-0.01em" }}>Log Intake</span>
        </div>
      </div>
    </WatchDarkBg>
  );
}

/* ─── Watch Slide 3: Fluid Picker ─── */
function WatchSlide3() {
  const drinks = [
    { icon: "💧", label: "Water", selected: true },
    { icon: "☕", label: "Coffee" },
    { icon: "🍵", label: "Tea" },
    { icon: "🧃", label: "Juice" },
    { icon: "🥛", label: "Milk" },
    { icon: "🫖", label: "Herbal" },
  ];
  return (
    <WatchDarkBg>
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: WH * 0.045, paddingBottom: WH * 0.04, paddingLeft: WW * 0.05, paddingRight: WW * 0.05 }}>
        <div style={{ fontSize: WW * 0.054, fontWeight: 700, color: "rgba(255,255,255,0.72)", textAlign: "center", letterSpacing: "0.02em", marginBottom: WH * 0.03, flexShrink: 0 }}>
          Choose Drink
        </div>
        <div style={{ flex: 1, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gridTemplateRows: "repeat(2, 1fr)", gap: WW * 0.028 }}>
          {drinks.map(({ icon, label, selected }) => (
            <div key={label} style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", borderRadius: WW * 0.065, background: selected ? "rgba(28,120,245,0.25)" : "rgba(255,255,255,0.06)", border: selected ? "1.5px solid rgba(28,120,245,0.6)" : "1.5px solid transparent", gap: WH * 0.008, padding: `${WH * 0.01}px ${WW * 0.01}px` }}>
              <span style={{ fontSize: WW * 0.1, lineHeight: 1 }}>{icon}</span>
              <span style={{ fontSize: WW * 0.036, fontWeight: 600, color: selected ? BRAND.lagoon : "rgba(255,255,255,0.55)", textAlign: "center" }}>{label}</span>
            </div>
          ))}
        </div>
      </div>
    </WatchDarkBg>
  );
}

/* ─── Watch Slide 4: Today's Log ─── */
function WatchSlide4() {
  const entries = [
    { icon: "💧", label: "Water", time: "9:32 AM", amount: "300 mL" },
    { icon: "☕", label: "Coffee", time: "11:15 AM", amount: "200 mL" },
    { icon: "🍵", label: "Tea", time: "2:08 PM", amount: "240 mL" },
    { icon: "💧", label: "Water", time: "4:45 PM", amount: "350 mL" },
  ];
  return (
    <WatchDarkBg>
      <div style={{ display: "flex", flexDirection: "column", height: "100%", paddingTop: WH * 0.045, paddingBottom: WH * 0.04, paddingLeft: WW * 0.06, paddingRight: WW * 0.06 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: WH * 0.025, flexShrink: 0 }}>
          <span style={{ fontSize: WW * 0.06, fontWeight: 700, color: "#FFFFFF" }}>Today</span>
          <span style={{ fontSize: WW * 0.062, fontWeight: 700, color: BRAND.lagoon }}>1.8 L</span>
        </div>
        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: WH * 0.012, overflow: "hidden" }}>
          {entries.map(({ icon, label, time, amount }, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: WW * 0.03, background: "rgba(255,255,255,0.055)", borderRadius: WW * 0.04, padding: `${WH * 0.016}px ${WW * 0.04}px` }}>
              <span style={{ fontSize: WW * 0.065, lineHeight: 1, flexShrink: 0 }}>{icon}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: WW * 0.046, fontWeight: 600, color: "#FFFFFF", lineHeight: 1.2 }}>{label}</div>
                <div style={{ fontSize: WW * 0.033, color: "rgba(255,255,255,0.36)", lineHeight: 1.2 }}>{time}</div>
              </div>
              <div style={{ fontSize: WW * 0.04, fontWeight: 600, color: BRAND.mint, flexShrink: 0 }}>{amount}</div>
            </div>
          ))}
        </div>
      </div>
    </WatchDarkBg>
  );
}

/* ─── Watch Slide 5: Goal Reached ─── */
function WatchSlide5() {
  const ringSize = WW * 0.50;
  const confetti = [
    { x: "14%", y: "10%", color: BRAND.lagoon, size: 6 },
    { x: "82%", y: "13%", color: BRAND.mint, size: 5 },
    { x: "7%", y: "66%", color: BRAND.sun, size: 7 },
    { x: "88%", y: "72%", color: BRAND.lagoon, size: 5 },
    { x: "50%", y: "5%", color: BRAND.mint, size: 4 },
    { x: "92%", y: "40%", color: BRAND.lavender, size: 4 },
    { x: "4%", y: "38%", color: BRAND.sun, size: 5 },
  ];
  return (
    <div style={{ width: WW, height: WH, position: "relative", overflow: "hidden", background: "linear-gradient(160deg, #0A1929 0%, #051224 100%)" }}>
      <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)", width: WW * 1.1, height: WW * 1.1, borderRadius: "50%", background: "radial-gradient(circle, rgba(48,194,163,0.26) 0%, transparent 65%)", pointerEvents: "none" }} />
      {confetti.map(({ x, y, color, size }, i) => (
        <div key={i} style={{ position: "absolute", left: x, top: y, width: size, height: size, borderRadius: "50%", background: color, opacity: 0.65 }} />
      ))}
      <div style={{ position: "relative", zIndex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", gap: WH * 0.022, padding: `0 ${WW * 0.08}px` }}>
        <div style={{ position: "relative", width: ringSize, height: ringSize, flexShrink: 0 }}>
          <WatchProgressRing progress={1.0} size={ringSize} id="ws5" />
          <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ fontSize: ringSize * 0.36, lineHeight: 1, color: BRAND.mint }}>✓</div>
          </div>
        </div>
        <div style={{ fontSize: WW * 0.085, fontWeight: 700, color: "#FFFFFF", textAlign: "center", lineHeight: 1.1, letterSpacing: "-0.02em" }}>
          Goal<br />Reached!
        </div>
        <div style={{ fontSize: WW * 0.062, fontWeight: 600, color: BRAND.mint }}>2.5 L today 🎉</div>
      </div>
    </div>
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

/**
 * Proposed screenshots not yet live on the App Store. Used for the
 * "Proposed (not live)" preview section so we can eyeball candidates
 * alongside production before promoting them into IPHONE_SCREENSHOTS.
 */
const PROPOSED_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "hero-v2", component: Slide1HeroV2 },
];

const IPAD_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "ipad-hero", component: IPadSlide1 },
  { name: "ipad-insights", component: IPadSlide2 },
  { name: "ipad-diary", component: IPadSlide3 },
  { name: "ipad-beverages", component: IPadSlide4 },
  { name: "ipad-widgets", component: IPadSlide5 },
];

const EARTH_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "earth-hero", component: EarthSlide1 },
  { name: "earth-banner", component: EarthSlide2 },
  { name: "earth-pledge", component: EarthSlide3 },
  { name: "earth-insights", component: EarthSlide4 },
  { name: "earth-facts", component: EarthSlide5 },
];

const WATCH_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "watch-dashboard", component: WatchSlide1 },
  { name: "watch-quick-add", component: WatchSlide2 },
  { name: "watch-beverages", component: WatchSlide3 },
  { name: "watch-log", component: WatchSlide4 },
  { name: "watch-goal-reached", component: WatchSlide5 },
];

/* ═══════════════════════════════════════════════════════
   APP STORE IN-APP EVENT ASSETS
   ═══════════════════════════════════════════════════════ */

/* Event Card — 16:9 landscape, min 1920x1080, max 3840x2160 */
const EVENT_CARD_W = 1920;
const EVENT_CARD_H = 1080;

const EVENT_CARD_SIZES = [
  { label: "Card (1920×1080)", w: 1920, h: 1080 },
] as const;

/* Event Details Page — 9:16 portrait, min 1080x1920, max 2160x3840 */
const EVENT_DETAIL_W = 1080;
const EVENT_DETAIL_H = 1920;

const EVENT_DETAIL_SIZES = [
  { label: "Details (1080×1920)", w: 1080, h: 1920 },
] as const;

/**
 * Event Card (1920×1080). Landscape — what users first see on the App
 * Store Today tab / search results. Headline stack left, tilted pledge
 * card right so it works alongside other promoted content.
 */
function EventCardSlide() {
  return (
    <EarthDarkBg w={EVENT_CARD_W} h={EVENT_CARD_H}>
      {/* Warm radial glow behind the pledge card */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `radial-gradient(circle at 72% 50%, rgba(56,160,107,0.50) 0%, rgba(10,77,56,0) 48%)`,
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "96px 120px",
          zIndex: 2,
        }}
      >
        {/* Left — headline stack */}
        <div style={{ maxWidth: 820, display: "flex", flexDirection: "column", gap: 28 }}>
          <div
            style={{
              display: "inline-flex",
              alignSelf: "flex-start",
              alignItems: "center",
              padding: "12px 26px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.18)",
              border: "1.5px solid rgba(255,255,255,0.3)",
              color: "#FFFFFF",
              fontSize: 24,
              fontWeight: 700,
              letterSpacing: "0.16em",
              textTransform: "uppercase",
            }}
          >
            🌿 Earth Week · Apr 20–26
          </div>

          <div
            style={{
              fontSize: 132,
              fontWeight: 800,
              color: "#FFFFFF",
              lineHeight: 0.92,
              letterSpacing: "-0.035em",
            }}
          >
            The Refill<br />Pledge.
          </div>

          <div
            style={{
              fontSize: 32,
              fontWeight: 500,
              color: "rgba(255,255,255,0.88)",
              lineHeight: 1.3,
              maxWidth: 760,
            }}
          >
            Refill, not rebuy. One small habit for Earth Week.
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: 16, marginTop: 12 }}>
            <img
              src="/app-icon.png"
              alt="Sipli"
              style={{ width: 56, height: 56, borderRadius: 14, display: "block" }}
            />
            <span style={{ fontSize: 32, fontWeight: 800, color: "#FFFFFF", letterSpacing: "-0.01em" }}>
              Sipli
            </span>
            <span
              style={{
                fontSize: 20,
                fontWeight: 600,
                color: "rgba(255,255,255,0.6)",
                marginLeft: 8,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
              }}
            >
              Available on the App Store
            </span>
          </div>
        </div>

        {/* Right — tilted pledge card mock */}
        <div
          style={{
            transform: "rotate(-3deg)",
            filter: "drop-shadow(0 40px 80px rgba(0,20,12,0.5))",
          }}
        >
          <RefillPledgeCard scale={0.95} name="Anoop" />
        </div>
      </div>
    </EarthDarkBg>
  );
}

/**
 * Event Details Page (1080×1920). Portrait — headline on top,
 * tilted pledge card below. This is what users see when they tap into
 * the event from the App Store before deciding to launch the app.
 */
function EventDetailsHeroSlide() {
  return (
    <EarthDarkBg w={EVENT_DETAIL_W} h={EVENT_DETAIL_H}>
      {/* Warm radial glow behind the pledge card */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `radial-gradient(circle at 50% 66%, rgba(56,160,107,0.55) 0%, rgba(10,77,56,0) 55%)`,
          pointerEvents: "none",
        }}
      />

      {/* Top accent — subtle leaf in the corner */}
      <div
        style={{
          position: "absolute",
          top: 80,
          right: 80,
          width: 120,
          height: 120,
          borderRadius: "50%",
          background: "rgba(255,255,255,0.10)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 64,
          zIndex: 2,
        }}
      >
        🌿
      </div>

      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          padding: "140px 80px 120px",
          zIndex: 3,
        }}
      >
        {/* Headline block — top */}
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            padding: "12px 26px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.18)",
            border: "1.5px solid rgba(255,255,255,0.3)",
            color: "#FFFFFF",
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: "0.16em",
            textTransform: "uppercase",
            marginBottom: 40,
          }}
        >
          🌿 Earth Week 2026
        </div>

        <div
          style={{
            fontSize: 124,
            fontWeight: 800,
            color: "#FFFFFF",
            lineHeight: 0.95,
            letterSpacing: "-0.035em",
            textAlign: "center",
            marginBottom: 32,
          }}
        >
          Take the<br />Refill Pledge.
        </div>

        <div
          style={{
            fontSize: 32,
            fontWeight: 500,
            color: "rgba(255,255,255,0.88)",
            lineHeight: 1.35,
            maxWidth: 860,
            textAlign: "center",
            marginBottom: 56,
          }}
        >
          Refill, not rebuy. Every refill is one less plastic bottle — and a habit that quietly sticks long after Earth Week ends.
        </div>

        {/* Tilted pledge card mock — middle/bottom */}
        <div
          style={{
            transform: "rotate(-3deg)",
            filter: "drop-shadow(0 40px 80px rgba(0,20,12,0.5))",
            marginBottom: "auto",
          }}
        >
          <RefillPledgeCard scale={1.05} name="Anoop" />
        </div>

        {/* Sipli lockup — absolute bottom */}
        <div
          style={{
            position: "absolute",
            bottom: 80,
            left: 0,
            right: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 10,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
            <img
              src="/app-icon.png"
              alt="Sipli"
              style={{ width: 64, height: 64, borderRadius: 15, display: "block" }}
            />
            <span style={{ fontSize: 36, fontWeight: 800, color: "#FFFFFF", letterSpacing: "-0.01em" }}>
              Sipli
            </span>
          </div>
          <div
            style={{
              fontSize: 22,
              fontWeight: 600,
              color: "rgba(255,255,255,0.6)",
              letterSpacing: "0.08em",
              textTransform: "uppercase",
            }}
          >
            Available on the App Store
          </div>
        </div>
      </div>
    </EarthDarkBg>
  );
}

const EVENT_CARD_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "event-card-earth-week", component: EventCardSlide },
];

const EVENT_DETAIL_SCREENSHOTS: ScreenshotEntry[] = [
  { name: "event-detail-earth-week", component: EventDetailsHeroSlide },
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
        title="Proposed (not live) 🧪"
        screenshots={PROPOSED_SCREENSHOTS}
        sizes={IPHONE_SIZES}
        canvasW={W}
        canvasH={H}
        filenamePrefix="iphone-proposed"
      />

      <DeviceSection
        title="iPhone — Earth Day 🌿"
        screenshots={EARTH_SCREENSHOTS}
        sizes={IPHONE_SIZES}
        canvasW={W}
        canvasH={H}
        filenamePrefix="iphone-earth"
      />

      <DeviceSection
        title="In-App Event — Card (1920×1080)"
        screenshots={EVENT_CARD_SCREENSHOTS}
        sizes={EVENT_CARD_SIZES}
        canvasW={EVENT_CARD_W}
        canvasH={EVENT_CARD_H}
        filenamePrefix="event"
      />

      <DeviceSection
        title="In-App Event — Details Page (1080×1920)"
        screenshots={EVENT_DETAIL_SCREENSHOTS}
        sizes={EVENT_DETAIL_SIZES}
        canvasW={EVENT_DETAIL_W}
        canvasH={EVENT_DETAIL_H}
        filenamePrefix="event"
      />

      <DeviceSection
        title="iPad"
        screenshots={IPAD_SCREENSHOTS}
        sizes={IPAD_SIZES}
        canvasW={IW}
        canvasH={IH}
        filenamePrefix="ipad"
      />

      <DeviceSection
        title="Apple Watch"
        screenshots={WATCH_SCREENSHOTS}
        sizes={WATCH_SIZES}
        canvasW={WW}
        canvasH={WH}
        filenamePrefix="watch"
      />

      <p style={{ textAlign: "center", color: "rgba(255,255,255,0.3)", marginTop: 40, fontSize: 13 }}>
        Click any screenshot to export all sizes for that device. Use &ldquo;Export All&rdquo; for a single size.
      </p>
    </div>
  );
}

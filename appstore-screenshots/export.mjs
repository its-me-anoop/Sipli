import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { mkdirSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = join(__dirname, 'exports');
mkdirSync(outDir, { recursive: true });

const W = 1290, H = 2796;

const labels = [
  'hero', 'log-intake', 'insights', 'diary', 'coach',
  'widgets-light', 'widgets-dark', 'beverages', 'weather', 'overview'
];

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();

  const htmlPath = `file://${join(__dirname, 'index.html')}`;
  await page.goto(htmlPath, { waitUntil: 'networkidle' });

  // Remove the toolbar, toast, and scaler transform so frames render at native 1290x2796
  await page.evaluate(() => {
    document.querySelector('.toolbar')?.remove();
    document.querySelector('.toast')?.remove();
    const scaler = document.getElementById('scaler');
    if (scaler) scaler.style.transform = 'none';
    const canvas = document.querySelector('.canvas');
    if (canvas) { canvas.style.paddingTop = '0'; canvas.style.padding = '0'; }
  });

  await page.waitForTimeout(2000);

  for (let i = 0; i < labels.length; i++) {
    // Show only the target frame
    await page.evaluate((idx) => {
      document.querySelectorAll('.frame').forEach(f => f.classList.remove('active'));
      document.getElementById('f' + idx).classList.add('active');
    }, i);

    await page.waitForTimeout(500);

    const frame = page.locator(`#f${i}`);
    const box = await frame.boundingBox();

    if (!box) {
      console.error(`Frame ${i} not visible, skipping`);
      continue;
    }

    const outPath = join(outDir, `sipli-${labels[i]}.png`);

    await page.screenshot({
      path: outPath,
      type: 'png',
      clip: { x: box.x, y: box.y, width: W, height: H },
    });

    console.log(`Exported: sipli-${labels[i]}.png  (${W}x${H})`);
  }

  await browser.close();
  console.log(`\nDone! All 10 screenshots at ${W}x${H} saved to:\n${outDir}`);
})();

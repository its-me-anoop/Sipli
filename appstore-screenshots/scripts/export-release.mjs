import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

// Uses the installed browser runtime; no app screenshots are resized or redrawn.
const runtime=process.env.PLAYWRIGHT_MODULE;
if(!runtime) throw new Error('Set PLAYWRIGHT_MODULE to an installed playwright/index.mjs.');
const {chromium}=await import(pathToFileURL(runtime).href);
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const release=path.join(root,'release-5.0.2');
const base=process.env.RELEASE_URL||pathToFileURL(path.join(release,'index.html')).href;
const browser=await chromium.launch({headless:true});
const devices=[['iphone',1320,2868,5,'APP_IPHONE_67'],['ipad13',2048,2732,3,'APP_IPAD_PRO_3GEN_129'],['ipad11',1668,2388,3,'APP_IPAD_PRO_3GEN_11']];
const manifest={version:'5.0.2',locales:{'en-US':{}}};
const checks=[];

// Chromium screenshots are opaque RGB. Assert their PNG header before upload.
function validatePNG(buffer,width,height){
  if(buffer.readUInt32BE(16)!==width||buffer.readUInt32BE(20)!==height||buffer[24]!==8||buffer[25]!==2||buffer[28]!==0)
    throw new Error(`Unexpected PNG format: ${buffer.readUInt32BE(16)}x${buffer.readUInt32BE(20)}, bitDepth ${buffer[24]}, colorType ${buffer[25]}, interlace ${buffer[28]}`);
}
try {
  for(const [device,width,height,count,displayType] of devices){
    const directory=path.join(release,device);
    await fs.mkdir(directory,{recursive:true});
    const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1,colorScheme:'light',reducedMotion:'reduce'});
    const paths=[];
    for(let slide=1;slide<=count;slide++){
      await page.goto(`${base}?device=${device}&slide=${slide}`,{waitUntil:'networkidle'});
      await page.evaluate(()=>window.releaseReady);
      const data=await page.evaluate(()=>{
        const main=document.querySelector('main');
        const heading=document.querySelector('h1').getBoundingClientRect();
        const shots=[...document.querySelectorAll('.device img')].map(image=>({file:image.getAttribute('src'),naturalWidth:image.naturalWidth,naturalHeight:image.naturalHeight,renderedWidth:image.getBoundingClientRect().width,renderedHeight:image.getBoundingClientRect().height}));
        return {name:main.dataset.filename,heading:{left:heading.left,right:heading.right,top:heading.top,bottom:heading.bottom},screens:shots};
      });
      if(data.screens.some(s=>!s.naturalWidth||Math.abs(s.renderedWidth/s.renderedHeight-s.naturalWidth/s.naturalHeight)>.001)) throw new Error('Missing or distorted source image');
      const filename=`${data.name}-${width}x${height}.png`;
      const target=path.join(directory,filename);
      const buffer=await page.locator('#slide').screenshot({path:target,animations:'disabled',omitBackground:false});
      validatePNG(buffer,width,height);
      paths.push(`appstore-screenshots/release-5.0.2/${device}/${filename}`);
      checks.push({device,width,height,...data,filename});
      console.log(`${device}: ${filename}`);
    }
    manifest.locales['en-US'][displayType]=paths;
    await page.close();
  }
  await fs.writeFile(path.join(release,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  await fs.writeFile(path.join(release,'export-checks.json'),JSON.stringify(checks,null,2)+'\n');
} finally {await browser.close();}

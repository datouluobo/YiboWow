const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp = require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');

async function main() {
  const skeleton=path.join(__dirname,'stage3-E-skeleton-draft.svg');
  const source=fs.readFileSync(skeleton);
  const browser=await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  try {
    const page=await browser.newPage({viewport:{width:952,height:720},deviceScaleFactor:1});
    await page.goto(pathToFileURL(path.join(__dirname,'stage3-preview.html')).href);
    await page.evaluate(()=>Promise.all(Array.from(document.images,img=>img.decode())));
    const dimensions=await page.locator('.tile img').evaluateAll(images=>images.map(img=>({width:img.getBoundingClientRect().width,height:img.getBoundingClientRect().height})));
    await page.screenshot({path:path.join(__dirname,'stage3-preview.png'),fullPage:true});
    const checks=[];
    for(const size of [24,32]){
      // In-memory diagnostic rendering only; no game texture or final export.
      const {data,info}=await sharp(source,{density:size/32*72}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      let edgeAlphaMax=0,minX=size,minY=size,maxX=-1,maxY=-1;
      for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const alpha=data[(y*size+x)*4+3];
        if(x===0||y===0||x===size-1||y===size-1)edgeAlphaMax=Math.max(edgeAlphaMax,alpha);
        if(alpha>=128){minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y)}
      }
      checks.push({size,edgeAlphaMax,visibleBounds:{minX,minY,maxX,maxY},channels:info.channels});
    }
    const report={status:'阶段3待确认',dimensions,checks};
    fs.writeFileSync(path.join(__dirname,'stage3-checks.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report));
  }finally{await browser.close()}
}
main().catch(error=>{console.error(error);process.exitCode=1});

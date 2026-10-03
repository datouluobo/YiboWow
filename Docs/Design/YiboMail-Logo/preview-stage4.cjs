const fs=require('fs');
const path=require('path');
const {pathToFileURL}=require('url');
const sharp=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {chromium}=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main(){
  const approved=fs.readFileSync(path.join(__dirname,'stage3-E-regular-hex-draft.svg'),'utf8');
  const source=approved.replace('id="frame" stroke="#49BCA5"','id="frame" stroke="#142328"');
  const outline=approved;
  fs.writeFileSync(path.join(__dirname,'stage4-E-outline-test.svg'),outline);
  const checks=[];
  for(const [variant,svg] of [['base',source],['outline',outline]])for(const size of [24,32,64]){
    const raster=sharp(Buffer.from(svg),{density:size/32*72});
    const png=await raster.png().toBuffer();
    fs.writeFileSync(path.join(__dirname,`stage4-E-${variant}-${size}-preview.png`),png);
    const {data,info}=await sharp(png).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let edgeAlphaMax=0;
    for(let y=0;y<size;y++)for(let x=0;x<size;x++)if(x===0||y===0||x===size-1||y===size-1)edgeAlphaMax=Math.max(edgeAlphaMax,data[(y*size+x)*4+3]);
    checks.push({variant,size,width:info.width,height:info.height,edgeAlphaMax});
  }
  const browser=await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  try{
    const page=await browser.newPage({viewport:{width:1040,height:850},deviceScaleFactor:1});
    await page.goto(pathToFileURL(path.join(__dirname,'stage4-preview.html')).href);
    await page.evaluate(()=>Promise.all(Array.from(document.images,image=>image.decode())));
    const actualSizes=await page.locator('img').evaluateAll(images=>images.map(image=>({width:image.getBoundingClientRect().width,height:image.getBoundingClientRect().height})));
    await page.screenshot({path:path.join(__dirname,'stage4-preview.png'),fullPage:true});
    const report={status:'阶段4待确认',geometry:'approved regular hexagon and unchanged E envelope paths; frame stroke color comparison',checks,actualSizes};
    fs.writeFileSync(path.join(__dirname,'stage4-checks.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report));
  }finally{await browser.close()}
}
main().catch(error=>{console.error(error);process.exitCode=1});

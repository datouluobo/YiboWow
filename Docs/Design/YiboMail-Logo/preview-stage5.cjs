const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {chromium}=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {pathToFileURL}=require('url');
async function main(){
  const source=path.join(__dirname,'stage5-E-style-source-draft.png');
  const checks=[];
  for(const size of [24,32,64]){
    const png=await sharp(source).resize(size,size,{kernel:'lanczos3'}).png().toBuffer();
    fs.writeFileSync(path.join(__dirname,`stage5-E-style-${size}-preview.png`),png);
    const {data,info}=await sharp(png).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let edgeAlphaMax=0,minX=size,minY=size,maxX=-1,maxY=-1;
    for(let y=0;y<size;y++)for(let x=0;x<size;x++){const a=data[(y*size+x)*4+3];if(x===0||y===0||x===size-1||y===size-1)edgeAlphaMax=Math.max(edgeAlphaMax,a);if(a>=128){minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y)}}
    checks.push({size,width:info.width,height:info.height,edgeAlphaMax,visibleBounds:{minX,minY,maxX,maxY}});
  }
  const browser=await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  try{const page=await browser.newPage({viewport:{width:960,height:620},deviceScaleFactor:1});await page.goto(pathToFileURL(path.join(__dirname,'stage5-preview.html')).href);await page.evaluate(()=>Promise.all(Array.from(document.images,img=>img.decode())));await page.screenshot({path:path.join(__dirname,'stage5-preview.png'),fullPage:true});fs.writeFileSync(path.join(__dirname,'stage5-checks.json'),JSON.stringify({status:'阶段5待确认',checks},null,2));console.log(JSON.stringify(checks))}finally{await browser.close()}
}
main().catch(e=>{console.error(e);process.exitCode=1});

const fs=require('fs'),path=require('path');
const {pathToFileURL}=require('url');
const sharp=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {chromium}=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main(){
  const source=fs.readFileSync(path.join(__dirname,'stage3-E-regular-hex-draft.svg'),'utf8');
  const frame=source.match(/<g id="frame"[\s\S]*?<path d="([^"]+)"/)[1];
  const values=frame.match(/\d+(?:\.\d+)?/g).map(Number);
  const [cx,top,right,y1,y2,,bottom,left,,y3]=values;
  const points=[[cx,top],[right,y1],[right,y2],[cx,bottom],[left,y2],[left,y3]];
  const edges=points.map((point,i)=>Math.hypot(point[0]-points[(i+1)%6][0],point[1]-points[(i+1)%6][1]));
  const angles=points.map((p,i)=>{const a=points[(i+5)%6],b=points[(i+1)%6];const u=[a[0]-p[0],a[1]-p[1]],v=[b[0]-p[0],b[1]-p[1]];return Math.acos((u[0]*v[0]+u[1]*v[1])/(Math.hypot(...u)*Math.hypot(...v)))*180/Math.PI});
  const checks=[];
  for(const size of [24,32]){const {data}=await sharp(Buffer.from(source),{density:size/32*72}).ensureAlpha().raw().toBuffer({resolveWithObject:true});let edgeAlphaMax=0;for(let y=0;y<size;y++)for(let x=0;x<size;x++)if(x===0||y===0||x===size-1||y===size-1)edgeAlphaMax=Math.max(edgeAlphaMax,data[(y*size+x)*4+3]);checks.push({size,edgeAlphaMax})}
  const report={points,edges,angles,maxEdgeDifference:Math.max(...edges)-Math.min(...edges),checks};
  if(report.maxEdgeDifference>0.00001||angles.some(a=>Math.abs(a-120)>0.0001))throw new Error('Regular hexagon geometry check failed');
  fs.writeFileSync(path.join(__dirname,'regular-hex-checks.json'),JSON.stringify(report,null,2));
  const browser=await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  try{const page=await browser.newPage({viewport:{width:880,height:580},deviceScaleFactor:1});await page.goto(pathToFileURL(path.join(__dirname,'regular-hex-preview.html')).href);await page.evaluate(()=>Promise.all(Array.from(document.images,img=>img.decode())));await page.screenshot({path:path.join(__dirname,'regular-hex-preview.png'),fullPage:true});console.log(JSON.stringify(report))}finally{await browser.close()}
}
main().catch(e=>{console.error(e);process.exitCode=1});

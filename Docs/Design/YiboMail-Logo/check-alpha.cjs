const path = require('path');
const sharp = require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const fs = require('fs');

async function main() {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname,'stage2-manifest.json'),'utf8'));
  const report = [];
  for (const item of manifest) {
    const source = path.join(__dirname,`stage2-${item.id}-draft.png`);
    const {data,info} = await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let edgeMax = 0;
    const alpha = (x,y)=>data[(y*info.width+x)*4+3];
    for (let x=0;x<info.width;x++) edgeMax=Math.max(edgeMax,alpha(x,0),alpha(x,info.height-1));
    for (let y=0;y<info.height;y++) edgeMax=Math.max(edgeMax,alpha(0,y),alpha(info.width-1,y));
    report.push({id:item.id,width:info.width,height:info.height,edgeAlphaMax:edgeMax});
  }
  fs.writeFileSync(path.join(__dirname,'stage2-alpha-check.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
}
main().catch(error=>{console.error(error);process.exitCode=1});

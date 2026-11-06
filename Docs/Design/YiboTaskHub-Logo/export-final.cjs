// Deterministic alpha cleanup, pixel diagnostics and format export.
const fs = require('fs');
const path = require('path');
const sharp = require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = __dirname;
const media = path.resolve(root, '../../../YiboTaskHub/Media');
const stem = 'YiboTaskHubIcon-v1';
async function main() {
  fs.mkdirSync(media, {recursive:true});
  const source = await sharp(path.join(root,'stage5-F-style-source-draft.png')).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const {width:w,height:h} = source.info;
  let left=w,top=h,right=0,bottom=0;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const i=(y*w+x)*4;
    if(source.data[i+3]<=8) source.data.fill(0,i,i+4);
    else {left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
  }
  const trimmed = await sharp(source.data,{raw:{width:w,height:h,channels:4}}).extract({left,top,width:right-left+1,height:bottom-top+1}).png().toBuffer();
  const evidence=[];
  for(const size of [24,32,64,128,512,1024]){
    const margin=Math.max(1,Math.round(size*0.035));
    // Restore the approved skeleton's outer 28:29 envelope after generator drift.
    const targetHeight=size-2*margin, targetWidth=Math.round(targetHeight*28/29);
    const leftMargin=Math.floor((size-targetWidth)/2);
    const rendered=await sharp(trimmed).resize(targetWidth,targetHeight,{fit:'fill'}).extend({top:margin,bottom:margin,left:leftMargin,right:size-targetWidth-leftMargin,background:{r:0,g:0,b:0,alpha:0}}).ensureAlpha().raw().toBuffer();
    for(let i=0;i<rendered.length;i+=4)if(rendered[i+3]<=8)rendered.fill(0,i,i+4);
    // Remove detached one/two-pixel specks in small game icons only.
    let removed=0;
    if(size<=32){
      const visited=new Uint8Array(size*size);
      for(let p=0;p<size*size;p++)if(!visited[p]&&rendered[p*4+3]){
        const queue=[p]; visited[p]=1;
        for(let j=0;j<queue.length;j++){
          const q=queue[j],x=q%size,y=Math.floor(q/size);
          for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
            const nx=x+dx,ny=y+dy,n=ny*size+nx;
            if(nx>=0&&nx<size&&ny>=0&&ny<size&&!visited[n]&&rendered[n*4+3]){visited[n]=1;queue.push(n);}
          }
        }
        if(queue.length<=2){removed+=queue.length;for(const q of queue)rendered.fill(0,q*4,q*4+4);}
      }
    }
    const file=path.join(media,`${stem}-${size}`);
    await sharp(rendered,{raw:{width:size,height:size,channels:4}}).png().toFile(file+'.png');
    // Uncompressed true-color TGA, top-left origin, 8 alpha bits.
    const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(size,12);header.writeUInt16LE(size,14);header[16]=32;header[17]=0x28;
    const bgra=Buffer.alloc(rendered.length);
    for(let i=0;i<rendered.length;i+=4){bgra[i]=rendered[i+2];bgra[i+1]=rendered[i+1];bgra[i+2]=rendered[i];bgra[i+3]=rendered[i+3];}
    fs.writeFileSync(file+'.tga',Buffer.concat([header,bgra]));
    let edge=0,l=size,t=size,r=0,b=0;
    for(let y=0;y<size;y++)for(let x=0;x<size;x++){
      const a=rendered[(y*size+x)*4+3];
      if(x===0||y===0||x===size-1||y===size-1)edge=Math.max(edge,a);
      if(a){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x+1);b=Math.max(b,y+1);}
    }
    if(edge)throw Error(`Nontransparent boundary at ${size}`);
    evidence.push({size,edgeAlphaMax:edge,bbox:[l,t,r,b],removedDetachedPixels:removed,png:`${stem}-${size}.png`,tga:`${stem}-${size}.tga`});
  }
  for(const ext of ['png','tga'])fs.copyFileSync(path.join(media,`${stem}-128.${ext}`),path.join(media,`${stem}.${ext}`));
  const skeleton=fs.readFileSync(path.join(root,'stage3-F-skeleton-draft.svg'),'utf8').replace('阶段 3 骨架待确认','v1 可编辑结构基准').replace('无材质或光效。','该 SVG 保存结构；手绘材质由对应 PNG/TGA 保存。');
  fs.writeFileSync(path.join(media,`${stem}-master.svg`),skeleton);
  fs.writeFileSync(path.join(root,'final-checks.json'),JSON.stringify({sourceCrop:[left,top,right+1,bottom+1],renders:evidence,defaultSize:128},null,2));
  console.log(JSON.stringify(evidence));
}
main().catch(e=>{console.error(e);process.exit(1);});

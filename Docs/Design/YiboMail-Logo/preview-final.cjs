const fs=require('fs'),path=require('path');
const {pathToFileURL}=require('url');
const {chromium}=require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main(){
  let html=fs.readFileSync(path.join(__dirname,'stage5-preview.html'),'utf8');
  html=html.replace('YiboMail · WoW 材质预览 · 待确认','YiboMail - 邮件助手 · Logo v1');
  html=html.replace('YiboMail · WoW 材质与光效','YiboMail - 邮件助手 · Logo v1');
  html=html.replace('阶段 5 · 待确认','阶段 7 · 已完成');
  html=html.replaceAll('stage5-E-style-source-draft.png','../../../YiboMail/Media/YiboMailIcon-v1-128.png');
  html=html.replace(/stage5-E-style-(24|32|64)-preview\.png/g,(_,size)=>`../../../YiboMail/Media/YiboMailIcon-v1-${size}.png`);
  html=html.replaceAll('WoW材质草案放大预览','YiboMail 正式图标');
  html=html.replace('放大检查 · 材质草案','128px · 正式资源');
  html=html.replace('[Yibo] YiboMail</span>','[Yibo] YiboMail - 邮件助手</span>');
  html=html.replace('请确认这版材质风格与小尺寸可读性。获批后进入像素级修整，检查边缘、断线与杂点。','24 / 32 / 64 / 128 / 512 / 1024px · PNG 与 TGA · SVG 骨架。全部保存在 YiboMail/Media，已更新插件引用。');
  const file=path.join(__dirname,'final-preview.html');fs.writeFileSync(file,html);
  const browser=await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  try{const page=await browser.newPage({viewport:{width:960,height:620},deviceScaleFactor:1});await page.goto(pathToFileURL(file).href);await page.evaluate(()=>Promise.all(Array.from(document.images,img=>img.decode())));await page.screenshot({path:path.join(__dirname,'final-preview.png'),fullPage:true});console.log('Final asset preview rendered')}finally{await browser.close()}
}
main().catch(error=>{console.error(error);process.exitCode=1});

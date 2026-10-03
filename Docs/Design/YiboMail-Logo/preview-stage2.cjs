const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');

// Presentation only: preserve generated silhouette PNGs without image edits.
async function main() {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, 'stage2-manifest.json'), 'utf8'));
  const cards = manifest.map(({ id, description }) => `<article>
    <header><b>${id}</b><span>${description}</span></header>
    <div class="concept"><img src="stage2-${id}-draft.png" alt="${id} 轮廓草案"></div>
    <div class="sizes"><div><img width="32" height="32" src="stage2-${id}-draft.png"><small>32 × 32</small></div><div><img width="24" height="24" src="stage2-${id}-draft.png"><small>24 × 24</small></div></div>
    <footer>4 个视觉块 · 外框 / 信封 / 封口 / 封蜡</footer>
  </article>`).join('');
  const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>YiboMail · 阶段 2 轮廓候选 · 待确认</title>
  <style>*{box-sizing:border-box}body{margin:0;background:#111b21;color:#eef0ec;font:15px "Microsoft YaHei",sans-serif;padding:32px}main{max-width:1152px;margin:auto}h1{font-size:26px;margin:0 0 8px}p{color:#aebcc0;margin:0 0 24px;line-height:1.7}.status{color:#5bd1b5}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}article{background:#1e2a30;border:1px solid #36454c;border-radius:12px;overflow:hidden}header{height:62px;display:flex;align-items:center;gap:12px;padding:14px}header b{font-size:24px;color:#6cd6bd}header span{font-size:13px;line-height:1.5}.concept{height:166px;display:flex;justify-content:center;align-items:center;background:#9eaaae}.concept img{width:144px;height:144px;object-fit:contain}.sizes{display:flex;align-items:center;justify-content:center;gap:42px;height:86px}.sizes div{display:flex;align-items:center;flex-direction:column;gap:8px}.sizes img{object-fit:contain}small{font-size:11px;color:#bac5c8}footer{font-size:10px;text-align:center;padding:0 8px 14px;color:#99a9b0}.note{margin:22px 0 0;font-size:13px}@media(max-width:850px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:480px){.grid{grid-template-columns:1fr}}</style>
  <main><h1>YiboMail · 信封轮廓探索</h1><p><span class="status">阶段 2 · 待确认</span>　只比较形状、角度和明暗；下方为 24 / 32 CSS 像素预览。<br>透明草案以黑白轮廓展示，144px 放大图用于比较轮廓；小尺寸骨架将在选定方向后重新建立。</p><section class="grid">${cards}</section><p class="note">候选为形状草案。最终暖象牙色纸张、琥珀金封蜡、青绿识别线与 WoW 材质在后续获批阶段实现。</p></main></html>`;
  const target = path.join(__dirname, 'stage2-preview.html');
  fs.writeFileSync(target, html.replace('<main>', '<style>.concept img,.sizes img{filter:grayscale(1) contrast(12)}</style><main>'), 'utf8');
  const browser = await chromium.launch({headless:true,executablePath:'C:/Users/Administrator/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe'});
  const page = await browser.newPage({viewport:{width:1216,height:1000},deviceScaleFactor:1});
  await page.goto(pathToFileURL(target).href);
  await page.evaluate(() => Promise.all(Array.from(document.images, image => image.decode())));
  await page.screenshot({path:path.join(__dirname,'stage2-preview.png'),fullPage:true});
  console.log(JSON.stringify({html:target, screenshot:path.join(__dirname,'stage2-preview.png')}));
  await browser.close();
}
main().catch(error=>{console.error(error);process.exitCode=1});

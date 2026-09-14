const { chromium } = require("playwright");
const fs = require("fs"),
  path = require("path");
(async () => {
  const browser = await chromium.launch({
    ...(process.env.CHROME_PATH
      ? { executablePath: process.env.CHROME_PATH }
      : {}),
    headless: true,
  });
  const page = await browser.newPage({
    viewport: { width: 1024, height: 1024 },
    deviceScaleFactor: 1,
  });
  const root = path.resolve(".");
  const svg = fs.readFileSync(root + "/Brand/mark.svg", "utf8");
  for (const [size, dest] of [
    [1024, "Artwork/Assets.xcassets/AppIcon.appiconset/AppIcon.png"],
    [256, "Brand/icon-256.png"],
    [180, "docs/assets/icon-180.png"],
    [120, "iOS/CodexDeck/Icon60@2x.png"],
    [180, "iOS/CodexDeck/Icon60@3x.png"],
    [152, "iOS/CodexDeck/Icon76@2x.png"],
    [167, "iOS/CodexDeck/Icon83.5@2x.png"],
  ]) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<style>body{margin:0;background:#253a32}svg{display:block;width:100vw;height:100vh}</style>${svg}`,
    );
    await page.screenshot({ path: root + "/" + dest });
  }
  await page.setViewportSize({ width: 1200, height: 630 });
  await page.setContent(
    `<style>*{box-sizing:border-box}body{margin:0;background:#f5f3ec;color:#253a32;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.card{height:630px;position:relative;overflow:hidden;padding:70px 78px}.brand{display:flex;align-items:center;gap:14px;font-size:21px;font-weight:600}.brand svg{width:44px;height:44px}.tag{font-size:13px;letter-spacing:3px;color:#77846a;margin:55px 0 21px}h1{font-size:68px;font-weight:580;letter-spacing:-3px;line-height:1.25;margin:0}h1 span{color:#788957}.foot{position:absolute;bottom:60px;left:78px;font-size:15px;color:#77846a}.big{position:absolute;right:83px;top:155px;width:290px;height:290px;transform:rotate(9deg);filter:drop-shadow(0 24px 26px #253a3220)}.big svg{width:100%;height:100%}.corner{position:absolute;right:-120px;top:85px;width:490px;height:490px;border-radius:110px;background:#e7ebdc;transform:rotate(9deg)}</style><div class="card"><div class="corner"></div><div class="brand">${svg}<span>Codex Deck</span></div><p class="tag">IPHONE + MAC · OPEN SOURCE</p><h1>工作在 Mac，<br><span>掌控在手边。</span></h1><div class="big">${svg}</div><p class="foot">One tap. Back to work. &nbsp; / &nbsp; flaricy.github.io/CodexDeck</p></div>`,
  );
  await page.screenshot({ path: root + "/docs/assets/social.png" });
  await browser.close();
  console.log("Rendered brand assets.");
})();

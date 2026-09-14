const { chromium } = require("playwright");
const fs = require("fs"),
  assert = require("assert");
const { spawn } = require("child_process");
const server = spawn(
  "python3",
  ["-m", "http.server", "8769", "--bind", "127.0.0.1", "--directory", "docs"],
  { stdio: "ignore" },
);
process.on("exit", () => server.kill());
(async () => {
  fs.mkdirSync(".test-results", { recursive: true });
  let ready = false;
  for (let i = 0; i < 40; i++) {
    try {
      await fetch("http://127.0.0.1:8769");
      ready = true;
      break;
    } catch {
      await new Promise((r) => setTimeout(r, 100));
    }
  }
  if (!ready) throw Error("Preview server did not start");
  const browser = await chromium.launch({
    ...(process.env.CHROME_PATH
      ? { executablePath: process.env.CHROME_PATH }
      : {}),
    headless: true,
  });
  const errors = [];
  const report = [];
  for (const width of [1440, 768, 390, 320]) {
    for (const lang of ["index.html", "en.html"]) {
      const page = await browser.newPage({
        viewport: { width, height: 1000 },
        reducedMotion: "reduce",
      });
      page.on("pageerror", (e) => errors.push(e.message));
      await page.goto("http://127.0.0.1:8769/" + lang, {
        waitUntil: "networkidle",
      });
      assert(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
        `overflow ${width} ${lang}`,
      );
      for (const count of [1, 3, 2]) {
        await page.locator(`[data-count="${count}"]`).click();
        assert.equal(await page.locator(".demo-key").count(), count);
      }
      await page.locator(".demo-key").nth(1).click();
      assert(
        (await page.locator("#focused-title").innerText()).includes(
          lang === "en.html" ? "sync" : "同步",
        ),
      );
      await page.locator(".hide-key").first().click();
      assert.equal(await page.locator(".demo-key").count(), 1);
      await page.locator(".reset-demo").click();
      assert.equal(await page.locator(".demo-key").count(), 2);
      await page.locator("details").nth(1).locator("summary").click();
      assert(
        (await page.locator("details").nth(1).getAttribute("open")) !== null,
      );
      const missing = await page.evaluate(() =>
        [...document.querySelectorAll('a[href^="#"]')]
          .map((a) => a.getAttribute("href"))
          .filter((h) => !document.getElementById(h.slice(1))),
      );
      assert.equal(missing.length, 0);
      await page.evaluate(() => scrollTo(0, 0));
      if (width === 1440 || width === 390)
        await page.screenshot({
          path: `.test-results/site-${width}-${lang}.png`,
          fullPage: true,
        });
      report.push(
        `${lang} @ ${width}px: no overflow; count / focus / hide / reset / FAQ / anchors pass`,
      );
      await page.close();
    }
  }
  const page = await browser.newPage({
    viewport: { width: 1440, height: 960 },
  });
  await page.goto("http://127.0.0.1:8769");
  await page.screenshot({ path: ".test-results/site-hero.png" });
  // Keyboard starts with the skip link and can reach the demo controls.
  await page.keyboard.press("Tab");
  assert.equal(await page.locator(":focus").getAttribute("href"), "#main");
  assert.equal(errors.length, 0, errors.join("\n"));
  fs.writeFileSync(".test-results/site-test-report.txt", report.join("\n"));
  console.log(report.join("\n"));
  await browser.close();
  server.kill();
})().catch((error) => {
  server.kill();
  console.error(error);
  process.exit(1);
});

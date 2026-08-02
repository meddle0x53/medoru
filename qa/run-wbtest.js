const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 800 } });
  page.on('console', m => console.log('CONSOLE:', m.text()));
  page.on('pageerror', e => console.log('PAGEERROR:', e.message));
  await page.goto('file:///tmp/wbtest/repro.html');
  await page.waitForSelector('#result', { timeout: 5000 });
  console.log(await page.textContent('#result'));
  await page.screenshot({ path: '/tmp/wbtest/shot.png', fullPage: true });
  await browser.close();
})();

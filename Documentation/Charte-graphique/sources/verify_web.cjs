// Run with NODE_PATH pointing to the bundled runtime's node_modules.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');

(async () => {
  const base = path.resolve(__dirname, '..');
  const kit = path.join(base, 'kit-web');
  const browser = await chromium.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-crash-reporter'],
  });
  const page = await browser.newPage({ deviceScaleFactor: 2 });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  const results = [];
  for (const width of [1280, 768, 390, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto(pathToFileURL(path.join(kit, 'index.html')).href);
    await page.evaluate(() => document.fonts.ready);
    const state = await page.evaluate(() => {
      const section = document.querySelector('.walkuno-feature');
      const cta = document.querySelector('.walkuno-feature__cta');
      const title = document.querySelector('.walkuno-feature__title');
      return {
        viewport: innerWidth,
        scrollWidth: document.documentElement.scrollWidth,
        columns: getComputedStyle(section).gridTemplateColumns,
        ctaHeight: cta.getBoundingClientRect().height,
        titleVisible: title.getBoundingClientRect().right <= innerWidth,
        images: [...document.images].every(i => i.complete && i.naturalWidth > 0),
      };
    });
    if (state.scrollWidth > width || !state.images || !state.titleVisible || state.ctaHeight < 48)
      throw new Error('Layout check failed: '+JSON.stringify(state));
    if ([1280,390].includes(width))
      await page.locator('.walkuno-feature').screenshot({
        path: path.join(kit, width===1280 ? 'apercu-ordinateur.png' : 'apercu-mobile.png'),
      });
    results.push(state);
  }
  await page.locator('.walkuno-feature__cta').focus();
  const focus = await page.locator('.walkuno-feature__cta').evaluate(e => ({
    outline: getComputedStyle(e).outlineWidth,
    visible: e.matches(':focus-visible'),
  }));
  await page.locator('.walkuno-feature__cta').click();
  if (!page.url().endsWith('#walkuno-details')) throw new Error('CTA anchor failed');
  if (errors.length) throw new Error(errors.join('\n'));
  fs.writeFileSync(path.join(base,'verification-web.json'),JSON.stringify({
    results,focus,ctaAnchor:true,errors,
  },null,2)+'\n');
  console.log(JSON.stringify({results,focus,ctaAnchor:true,errors}));
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });

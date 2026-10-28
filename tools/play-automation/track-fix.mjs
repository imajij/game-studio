const APPID = "__APPID__";
const TRACK = "__TRACK__";
const task = await taskSpace(4);
const page = task.page("p1");
const sleep = (ms) => page.waitForTimeout(ms);
const log = (...a) => console.log("[fix]", ...a);
const clickAt = async (p, label) => { await page.mouse.click(p.x, p.y, { label }); await sleep(900); };
const savePos = () => page.evaluate(() => {
  const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === "Save" && !x.disabled).pop();
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
});

// ---- countries
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/tracks/${TRACK}?tab=countryAvailability`);
await page.waitForLoadState();
await sleep(6000);
{
  const already = await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/Targeted \(\d+\)/)?.[0]);
  if (already) { log("countries already:", already); }
  else {
    const a = await page.evaluate(() => {
      const el = [...document.querySelectorAll("a, button")].find(x => x.offsetParent && x.textContent.trim() === "Add countries / regions");
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (a) { await sleep(300); await clickAt(a, "open countries editor"); await sleep(3500); }
    const hd = await page.evaluate(() => {
      const cell = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Country / region" && e.offsetParent).pop();
      if (!cell) return null;
      cell.scrollIntoView({ block: "center" });
      const r = cell.getBoundingClientRect();
      return { x: r.x - 33, y: r.y + r.height / 2 };
    });
    if (hd) {
      await sleep(500);
      const hd2 = await page.evaluate(() => {
        const cell = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Country / region" && e.offsetParent).pop();
        const r = cell.getBoundingClientRect();
        return { x: r.x - 33, y: r.y + r.height / 2 };
      });
      await clickAt(hd2, "select all countries");
      await sleep(1500);
      const sv = await savePos();
      if (sv) { await clickAt(sv, "save countries"); await sleep(4500); }
    } else log("header miss");
    log("countries:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/Targeted \(\d+\)/)?.[0]));
  }
}
// ---- testers
{
  const t = await page.evaluate(() => {
    const els = [...document.querySelectorAll("*")].filter(x => x.offsetParent && x.children.length === 0 && x.textContent.trim() === "Testers");
    const el = els.find(x => { const r = x.getBoundingClientRect(); return r.height > 5 && r.height < 60 && r.y > 100; });
    if (!el) return null;
    el.scrollIntoView({ block: "center" });
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (t) {
    await sleep(400);
    const t2 = await page.evaluate(() => {
      const els = [...document.querySelectorAll("*")].filter(x => x.offsetParent && x.children.length === 0 && x.textContent.trim() === "Testers");
      const el = els.find(x => { const r = x.getBoundingClientRect(); return r.height > 5 && r.height < 60 && r.y > 100; });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    await clickAt(t2, "open testers tab");
    await sleep(3500);
    const row = await page.evaluate(() => {
      const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Zintara testers" && e.offsetParent).pop();
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x - 35, y: r.y + r.height / 2 };
    });
    if (row) {
      await sleep(400);
      const row2 = await page.evaluate(() => {
        const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Zintara testers" && e.offsetParent).pop();
        const r = el.getBoundingClientRect();
        return { x: r.x - 35, y: r.y + r.height / 2 };
      });
      await clickAt(row2, "check Zintara testers");
      await sleep(1200);
    } else log("tester row miss");
    const fi = await page.evaluate(() => {
      const label = [...document.querySelectorAll("*")].find(e => e.children.length === 0 && e.textContent.trim() === "Feedback URL or email address");
      if (!label) return null;
      let el = label;
      for (let k = 0; k < 6 && el.parentElement; k++) {
        el = el.parentElement;
        const i = el.querySelector("input, textarea");
        if (i) { i.scrollIntoView({ block: "center" }); const r = i.getBoundingClientRect(); return { x: r.x + 20, y: r.y + r.height / 2, has: !!i.value }; }
      }
      return null;
    });
    if (fi && !fi.has) {
      await sleep(300);
      await clickAt(fi, "focus feedback");
      await page.keyboard.type("ajijuttam2006@gmail.com");
      await sleep(600);
    }
    const sv = await savePos();
    if (sv) { await clickAt(sv, "save testers"); await sleep(3500); }
    log("progress:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/\d of 4 complete/)?.[0]));
  } else log("testers tab miss");
}
// ---- release review save
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/tracks/${TRACK}/releases/1/review`);
await page.waitForLoadState();
await sleep(6000);
log("review:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/\d Errors?|\d Warnings?/g)?.slice(0, 3)));
{
  const sv = await page.evaluate(() => {
    const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === "Save" && !x.disabled).pop();
    if (!el) return null;
    el.scrollIntoView({ block: "center" });
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (sv) { await sleep(400); await clickAt(sv, "save release"); await sleep(5500); }
  await page.keyboard.press("Escape");
  await sleep(1000);
  log("state:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/(Not yet sent for review|Changes have been saved|problems with your release).{0,40}/)?.[0]));
}

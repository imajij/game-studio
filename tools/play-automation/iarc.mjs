const APPID = "__APPID__";
const VIOLENCE = __VIOLENCE__; // true only for Snack Slasher
const task = await taskSpace(4);
const page = task.page("p1");
const sleep = (ms) => page.waitForTimeout(ms);
const log = (...a) => console.log("[iarc]", ...a);
const clickAt = async (p, label) => { await page.mouse.click(p.x, p.y, { label }); await sleep(900); };
const btnPos = (t) => page.evaluate((w) => {
  const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === w && !x.disabled).pop();
  if (!el) return null;
  el.scrollIntoView({ block: "center" });
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
}, t);

await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/app-content/content-rating-overview`);
await page.waitForLoadState();
await sleep(5000);
// open questionnaire: "Start questionnaire", or "Edit" on existing draft
let opened = false;
for (const t of ["Start questionnaire", "Edit", "Start new questionnaire"]) {
  const p = await btnPos(t);
  if (p) { await sleep(300); await clickAt(p, t); opened = true; break; }
}
log("opened:", opened);
await sleep(4500);

// CATEGORY page: email, Game, terms
await page.fill("input[type=email]", "ajijuttam2006@gmail.com").catch(() => {});
await page.evaluate(() => {
  [...document.querySelectorAll("material-radio")].find(r => r.textContent.trim().startsWith("Game"))?.click();
});
await sleep(700);
{
  const tc = await page.evaluate(() => {
    const c = document.querySelector("material-checkbox");
    if (c && c.getAttribute("aria-checked") !== "true") {
      c.scrollIntoView({ block: "center" });
      const r = (c.querySelector(".mdc-checkbox") || c).getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }
    return null;
  });
  if (tc) { await sleep(300); await clickAt(tc, "IARC terms"); }
  const nx = await btnPos("Next");
  if (nx) { await sleep(300); await clickAt(nx, "to questionnaire"); }
  await sleep(4500);
}

// QUESTIONNAIRE: answer each group
{
  const n = await page.evaluate((violence) => {
    let count = 0;
    for (const g of document.querySelectorAll("material-radio-group, [role=radiogroup]")) {
      let ctx = "";
      let el = g;
      for (let k = 0; k < 5 && el.parentElement; k++) { el = el.parentElement; const t = el.textContent.trim().replace(/\s+/g, " "); if (t.length > 40) { ctx = t; break; } }
      const wantYes = violence && /violence, blood, or gory/.test(ctx);
      const target = [...g.querySelectorAll("material-radio")].find(r => r.textContent.trim() === (wantYes ? "Yes" : "No"));
      if (target) { target.click(); count++; }
    }
    return count;
  }, VIOLENCE);
  log("answered:", n);
  await sleep(1500);
  if (VIOLENCE) {
    // violence=Yes reveals sub-questions; print them for manual verification
    const subs = await page.evaluate(() =>
      [...document.querySelectorAll("material-radio-group, [role=radiogroup]")].map(g => {
        let el = g, ctx = "";
        for (let k = 0; k < 5 && el.parentElement; k++) { el = el.parentElement; const t = el.textContent.trim().replace(/\s+/g, " "); if (t.length > 40) { ctx = t.slice(0, 120); break; } }
        const checked = !![...g.querySelectorAll("[aria-checked='true'], input:checked")].length;
        return (checked ? "[x] " : "[ ] ") + ctx;
      }));
    log("SUBQUESTIONS:\n" + subs.join("\n"));
  }
  // verify none unanswered; report
  const un = await page.evaluate(() =>
    [...document.querySelectorAll("material-radio-group, [role=radiogroup]")]
      .filter(g => ![...g.querySelectorAll("[aria-checked='true'], input:checked")].length).length);
  log("unanswered:", un);
  const nx = await btnPos("Next");
  if (nx) { await sleep(300); await clickAt(nx, "to summary"); await sleep(5000); }
}
// SUMMARY: Save
{
  const sv = await btnPos("Save");
  if (sv) { await sleep(300); await clickAt(sv, "save rating"); await sleep(5000); }
  let ok = await page.evaluate(() => document.body.innerText.includes("Submitted"));
  if (!ok) {
    for (const w of ["Next", "Save"]) {
      const b = await btnPos(w);
      if (b) { await sleep(400); await clickAt(b, w + " retry"); await sleep(5500); }
    }
    ok = await page.evaluate(() => document.body.innerText.includes("Submitted"));
  }
  log("submitted:", ok);
}

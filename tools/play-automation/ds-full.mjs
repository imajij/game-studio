const APPID = "__APPID__";
const task = await taskSpace(4);
const page = task.page("p1");
const sleep = (ms) => page.waitForTimeout(ms);
const log = (...a) => console.log("[ds]", ...a);
const clickAt = async (p, label) => { await page.mouse.click(p.x, p.y, { label }); await sleep(900); };
const btnPos = (t) => page.evaluate((w) => {
  const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === w && !x.disabled).pop();
  if (!el) return null;
  el.scrollIntoView({ block: "center" });
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
}, t);

await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/app-content/data-privacy-security`);
await page.waitForLoadState();
await sleep(5500);
// dismiss carousel if present (centered buttons)
for (let i = 0; i < 6; i++) {
  const b = await page.evaluate(() => {
    for (const n of ["Start", "Next"]) {
      const els = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === n);
      for (const el of els) {
        const r = el.getBoundingClientRect();
        if (r.y > 300 && r.y < 720 && r.x > 420 && r.x < 1080) return { x: r.x + r.width / 2, y: r.y + r.height / 2, t: n };
      }
    }
    return null;
  });
  if (!b) break;
  await clickAt(b, "carousel " + b.t);
  if (b.t === "Start") break;
}
await sleep(1200);
// step 1 overview -> Next
{
  const onStep1 = await page.evaluate(() => /Step 1 of 5/.test(document.body.innerText));
  if (onStep1) {
    const nx = await btnPos("Next");
    if (nx) { await clickAt(nx, "to step 2"); await sleep(4500); }
  }
}
// step 2: iterative dynamic answering
for (let round = 0; round < 10; round++) {
  const acted = await (async () => {
    const groups = await page.evaluate(() => {
      const inputs = [...document.querySelectorAll("input.mdc-radio__native-control")];
      const byName = new Map();
      for (const i of inputs) {
        const n = i.getAttribute("name");
        if (!byName.has(n)) byName.set(n, { opts: [], checked: false });
        const g = byName.get(n);
        g.opts.push((i.closest("material-radio")?.textContent.trim().replace(/\s+/g, " ") || "").slice(0, 50));
        if (i.getAttribute("aria-checked") === "true") g.checked = true;
      }
      return [...byName.entries()].map(([n, g]) => ({ n, ...g }));
    });
    // collect=Yes single-option group
    for (const g of groups) {
      if (g.opts.length === 1 && g.opts[0] === "Yes" && !g.checked) {
        const get = () => page.evaluate((n) => {
          const i = [...document.querySelectorAll("input.mdc-radio__native-control")].find(x => x.getAttribute("name") === n);
          if (!i) return null;
          i.scrollIntoView({ block: "center" });
          const r = i.getBoundingClientRect();
          return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
        }, g.n);
        let p = await get();
        if (!p) continue;
        await sleep(450);
        p = await get();
        await clickAt(p, "collect=Yes");
        log("answered collect");
        return true;
      }
    }
    let yn = 0;
    for (const g of groups) {
      const isYN = g.opts.length === 2 && g.opts[0] === "Yes" && g.opts[1] === "No";
      let kind = null;
      if (g.opts.length === 3) kind = "deletion";
      else if (g.opts.some(o => o.startsWith("Yes'Committed"))) kind = "families";
      else if (isYN) { yn++; kind = yn === 1 ? "encrypted" : "accounts"; }
      if (!kind || g.checked) continue;
      const ans = kind === "encrypted" ? "Yes" : kind === "families" ? "Yes'Committed" : "No";
      const get = () => page.evaluate(([n, a]) => {
        const i = [...document.querySelectorAll("input.mdc-radio__native-control")].find(x => x.getAttribute("name") === n &&
          (x.closest("material-radio")?.textContent.trim().replace(/\s+/g, " ") || "").startsWith(a));
        if (!i) return null;
        i.scrollIntoView({ block: "center" });
        const r = i.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      }, [g.n, ans]);
      let p = await get();
      if (!p) continue;
      await sleep(450);
      p = await get();
      await clickAt(p, kind + "=" + ans.slice(0, 6));
      log("answered", kind);
      return true;
    }
    return false;
  })();
  if (!acted) break;
  await sleep(1200);
}
{
  const nx = await btnPos("Next");
  log("step2 complete:", !!nx);
  if (nx) { await sleep(300); await clickAt(nx, "to data types"); await sleep(5000); }
}
// step 3: data types
{
  const PLAN = [
    ["App activity", "App interactions"],
    ["App info and performance", "Diagnostics"],
    ["Device or other IDs", "Device or other IDs"],
  ];
  for (const [cat, box] of PLAN) {
    const sh = await page.evaluate((c) => {
      const title = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === c).pop();
      if (!title) return null;
      let row = title;
      for (let k = 0; k < 8 && row.parentElement; k++) {
        row = row.parentElement;
        const show = [...row.querySelectorAll("*")].find(x => x.children.length === 0 && x.textContent.trim() === "Show");
        if (show) { show.scrollIntoView({ block: "center" }); const r = show.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }
      }
      return null;
    }, cat);
    if (!sh) { log("show miss", cat); continue; }
    await sleep(400);
    await clickAt(sh, "show " + cat);
    await sleep(1300);
    const get = () => page.evaluate((b) => {
      const c = [...document.querySelectorAll("material-checkbox")].find(x =>
        x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(b) &&
        !(x.querySelector("input:checked, [aria-checked='true']") || x.getAttribute("aria-checked") === "true"));
      if (!c) return null;
      c.scrollIntoView({ block: "center" });
      const box2 = c.querySelector(".mdc-checkbox") || c;
      const r = box2.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, box);
    let cb = await get();
    if (!cb) { log("cb miss/checked", box); continue; }
    await sleep(400);
    cb = await get();
    await clickAt(cb, "check " + box);
    log("selected", box);
  }
  const nx = await btnPos("Next");
  log("step3 complete:", !!nx);
  if (nx) { await sleep(300); await clickAt(nx, "to usage"); await sleep(5000); }
}
// step 4: per-type dialogs
const fillDialog = async (purposes, label) => {
  for (const c of ["Collected", "Shared"]) {
    const q = await page.evaluate((t) => {
      const el = [...document.querySelectorAll("material-checkbox")].find(x => x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(t) && !x.querySelector("input:checked, [aria-checked='true']"));
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const b = el.querySelector(".mdc-checkbox") || el;
      const r = b.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, c);
    if (q) await clickAt(q, "check " + c);
  }
  for (const rt of ["No, this collected data is not processed", "Data collection is required"]) {
    const q = await page.evaluate((t) => {
      const m = [...document.querySelectorAll("material-radio")].find(x => x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(t));
      if (!m) return null;
      m.scrollIntoView({ block: "center" });
      const b = m.querySelector(".mdc-radio") || m;
      const r = b.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, rt);
    if (q) await clickAt(q, rt.slice(0, 18)); else log("dlg radio miss", label, rt.slice(0, 18));
  }
  for (let i = 0; i < 8; i++) {
    const q = await page.evaluate((want) => {
      const c = [...document.querySelectorAll("material-checkbox")].find(x =>
        x.offsetParent && want.some(w => x.textContent.trim().replace(/\s+/g, " ").startsWith(w)) &&
        !x.querySelector("input:checked, [aria-checked='true']"));
      if (!c) return null;
      c.scrollIntoView({ block: "center" });
      const b = c.querySelector(".mdc-checkbox") || c;
      const r = b.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, purposes);
    if (!q) break;
    await sleep(300);
    await clickAt(q, "purpose");
  }
  const s = await btnPos("Save");
  if (s) await clickAt(s, "save " + label); else log("dlg save miss", label);
  await sleep(2500);
};
{
  const ROWS = [
    ["App activity", "App interactions", ["Advertising or marketing", "Analytics"]],
    ["App info and performance", "Diagnostics", ["Analytics"]],
    ["Device or other IDs", "Device or other IDs", ["Advertising or marketing", "Fraud prevention, security, and compliance"]],
  ];
  for (const [section, row, purposes] of ROWS) {
    const sh = await page.evaluate((c) => {
      const title = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === c).pop();
      if (!title) return null;
      let r0 = title;
      for (let k = 0; k < 8 && r0.parentElement; k++) {
        r0 = r0.parentElement;
        const show = [...r0.querySelectorAll("*")].find(x => x.children.length === 0 && x.textContent.trim() === "Show");
        if (show) { show.scrollIntoView({ block: "center" }); const r = show.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }
      }
      return null;
    }, section);
    if (sh) { await sleep(300); await clickAt(sh, "show " + section); await sleep(1300); }
    const getArrow = () => page.evaluate((rowName) => {
      const cell = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === rowName && e.offsetParent).pop();
      if (!cell) return null;
      let r0 = cell;
      for (let k = 0; k < 6 && r0.parentElement; k++) {
        r0 = r0.parentElement;
        const arrow = [...r0.querySelectorAll("*")].find(e => e.children.length === 0 && e.textContent.trim() === "arrow_right_alt" && e.offsetParent);
        if (arrow) { arrow.scrollIntoView({ block: "center" }); const r = arrow.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }
      }
      return null;
    }, row);
    let ar = await getArrow();
    if (!ar) { log("row arrow miss", row); continue; }
    await sleep(400);
    ar = await getArrow();
    await clickAt(ar, "open " + row);
    await sleep(1800);
    await fillDialog(purposes, row);
  }
}
// step 5: preview + save
{
  const nx = await btnPos("Next");
  if (nx) { await sleep(300); await clickAt(nx, "to preview"); await sleep(5000); }
  const sv = await btnPos("Save");
  if (sv) { await sleep(300); await clickAt(sv, "save data safety"); await sleep(4500); }
  log("saved:", await page.evaluate(() => document.body.innerText.includes("Change saved")));
}

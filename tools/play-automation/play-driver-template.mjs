// __CATEGORY__, __MDIR__, __AAB__, __NOTES__, __NSHOTS__
const APPID = "__APPID__";
const BASE = `https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}`;
const MDIR = "__MDIR__";
const task = await taskSpace(4);
const page = task.page("p1");

const log = (...a) => console.log("[__NAME__]", ...a);
const sleep = (ms) => page.waitForTimeout(ms);
const clickAt = async (p, label) => { await page.mouse.click(p.x, p.y, { label }); await sleep(900); };
const lastBtn = (text) => page.evaluate((t) => {
  const el = [...document.querySelectorAll("button, a, [role=button]")].filter(x => x.offsetParent && x.textContent.trim() === t && !x.disabled).pop();
  if (!el) return null;
  el.scrollIntoView({ block: "center" });
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
}, text);
const clickBtn = async (text, label) => {
  const p = await lastBtn(text);
  if (!p) { log("BTN MISS", text); return false; }
  await sleep(300);
  const p2 = await lastBtn(text);
  if (!p2) { log("BTN GONE", text); return false; }
  await clickAt(p2, label || text);
  return true;
};
const saved = () => page.evaluate(() => document.body.innerText.includes("Change saved"));
const evalClickRadio = (startText) => page.evaluate((t) => {
  const r = [...document.querySelectorAll("material-radio")].find(x => x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(t));
  if (!r) return false;
  r.click();
  return true;
}, startText);
const mouseRadio = async (startText, label) => {
  const p = await page.evaluate((t) => {
    const m = [...document.querySelectorAll("material-radio")].find(x => x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(t));
    if (!m) return null;
    m.scrollIntoView({ block: "center" });
    const b = m.querySelector(".mdc-radio") || m;
    const r = b.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, startText);
  if (!p) { log("RADIO MISS", startText); return false; }
  await sleep(300);
  await clickAt(p, label || startText.slice(0, 20));
  return true;
};
const mouseCheckbox = async (startText, label) => {
  const p = await page.evaluate((t) => {
    const c = [...document.querySelectorAll("material-checkbox")].find(x => x.offsetParent && x.textContent.trim().replace(/\s+/g, " ").startsWith(t) &&
      !(x.querySelector("input:checked, [aria-checked='true']") || x.getAttribute("aria-checked") === "true"));
    if (!c) return null;
    c.scrollIntoView({ block: "center" });
    const b = c.querySelector(".mdc-checkbox") || c;
    const r = b.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, startText);
  if (!p) { log("CB skip/miss", startText); return false; }
  await sleep(300);
  await clickAt(p, label || startText.slice(0, 20));
  return true;
};
const gotoOverviewAndStart = async (declLabel) => {
  await page.goto(`${BASE}/app-content/overview`);
  await page.waitForLoadState();
  await sleep(4500);
  const ok = await page.evaluate((l) => {
    const b = document.querySelector(`button[aria-label='${l}']`);
    if (b) { b.click(); return true; }
    return false;
  }, declLabel);
  await sleep(4500);
  return ok;
};

// ---- 1. privacy policy
await page.goto(`${BASE}/app-content/privacy-policy`);
await page.waitForLoadState();
await sleep(4000);
await page.evaluate(() => { const i = [...document.querySelectorAll("input")].find(x => x.offsetParent && x.type !== "checkbox"); i.focus(); });
await page.fill("css=input[type=text] >> nth=0", "https://imajij.github.io/privacy.html").catch(async () => {
  const i = await page.evaluate(() => {
    const el = [...document.querySelectorAll("input")].find(x => x.offsetParent && x.type !== "checkbox");
    const r = el.getBoundingClientRect();
    return { x: r.x + 20, y: r.y + r.height / 2 };
  });
  await clickAt(i, "focus privacy url");
  await page.keyboard.type("https://imajij.github.io/privacy.html");
});
await sleep(500);
await page.evaluate(() => {
  const b = [...document.querySelectorAll("button")].find(x => x.textContent.trim() === "Save" && !x.disabled);
  b?.click();
});
await sleep(3000);
log("privacy saved:", await saved());

// ---- 2. ads declaration
await page.goto(`${BASE}/app-content/ads-declaration`);
await page.waitForLoadState();
await sleep(4000);
await evalClickRadio("Yes, my app contains ads");
await sleep(700);
await page.evaluate(() => { const b = [...document.querySelectorAll("button")].find(x => x.textContent.trim() === "Save" && !x.disabled); b?.click(); });
await sleep(3000);
log("ads saved:", await saved());

// ---- 3. app access
await page.goto(`${BASE}/app-content/testing-credentials`);
await page.waitForLoadState();
await sleep(4000);
await evalClickRadio("No");
await sleep(700);
await page.evaluate(() => { const b = [...document.querySelectorAll("button")].find(x => x.textContent.trim() === "Save" && !x.disabled); b?.click(); });
await sleep(3000);
log("app access saved:", await saved());

// ---- 4. content rating (IARC) — all No (template-level; snack handled separately)
if (await gotoOverviewAndStart("Start Content ratings declaration")) {
  await page.evaluate(() => { const b = [...document.querySelectorAll("button")].find(x => x.textContent.trim() === "Start questionnaire"); b?.click(); });
  await sleep(4000);
  await page.fill("input[type=email]", "ajijuttam2006@gmail.com");
  await page.evaluate(() => {
    [...document.querySelectorAll("material-radio")].find(r => r.textContent.trim().startsWith("Game"))?.click();
    const c = document.querySelector("material-checkbox");
    if (c && c.getAttribute("aria-checked") !== "true") c.click();
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
    if (tc) { await sleep(300); await clickAt(tc, "IARC terms checkbox"); }
    const nx0 = await lastBtn("Next");
    if (nx0) { await clickAt(nx0, "IARC next"); }
  }
  await sleep(4000);
  const n = await page.evaluate(() => {
    let count = 0;
    for (const g of document.querySelectorAll("material-radio-group, [role=radiogroup]")) {
      const no = [...g.querySelectorAll("material-radio")].find(r => r.textContent.trim() === "No");
      if (no) { no.click(); count++; }
    }
    return count;
  });
  log("IARC answered No:", n);
  await sleep(900);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(4500);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Save" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(4000);
  log("IARC submitted:", await page.evaluate(() => document.body.innerText.includes("Submitted")));
} else log("IARC start missing");

// ---- 5. target audience
if (await gotoOverviewAndStart("Start Target audience and content declaration")) {
  await page.evaluate(() => {
    const want = ["6-8", "9-12", "13-15", "16-17", "18 and over"];
    for (const c of document.querySelectorAll("material-checkbox")) {
      if (want.includes(c.textContent.trim()) && c.getAttribute("aria-checked") !== "true") c.click();
    }
  });
  await sleep(900);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(2500);
  await page.evaluate(() => {
    const d = document.querySelector("[role=dialog], material-dialog");
    const ok = [...(d || document).querySelectorAll("button")].find(b => b.textContent.trim() === "OK");
    ok?.click();
  });
  await sleep(2500);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(3000);
  await page.evaluate(() => { const c = document.querySelector("material-checkbox"); if (c && c.getAttribute("aria-checked") !== "true") c.click(); });
  await sleep(700);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(3500);
  await evalClickRadio("Yes");
  await sleep(700);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(3500);
  await page.evaluate(() => { [...document.querySelectorAll("material-radio")].find(r => r.textContent.includes("Do not include"))?.click(); });
  await sleep(700);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Next" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(3500);
  await page.evaluate(() => { const bs = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Save" && !x.disabled); bs[bs.length - 1]?.click(); });
  await sleep(3500);
  log("target audience saved:", await saved());
} else log("target audience start missing");

// ---- 7. advertising ID
if (await gotoOverviewAndStart("Start Advertising ID declaration")) {
  await mouseRadio("Yes", "ad id yes");
  await mouseCheckbox("Advertising or marketing", "purpose advertising");
  await mouseCheckbox("Fraud prevention, security, and compliance", "purpose fraud");
  const sv = await lastBtn("Save");
  if (sv) await clickAt(sv, "save ad id");
  await sleep(3000);
  log("ad id saved:", await saved());
} else log("ad id start missing (maybe already done)");

// ---- 8. government
if (await gotoOverviewAndStart("Start Government apps declaration")) {
  await evalClickRadio("No");
  await sleep(700);
  await page.evaluate(() => { const b = [...document.querySelectorAll("button")].find(x => x.textContent.trim() === "Save" && !x.disabled); b?.click(); });
  await sleep(3000);
  log("gov saved:", await saved());
}

// ---- 9. financial
if (await gotoOverviewAndStart("Start Financial features declaration")) {
  await mouseCheckbox("My app doesn't provide any financial features", "no financial features");
  const nx = await lastBtn("Next");
  if (nx) { await clickAt(nx, "next"); await sleep(3500); }
  const sv = await lastBtn("Save");
  if (sv) await clickAt(sv, "save financial");
  await sleep(3000);
  log("financial saved:", await saved());
}

// ---- 10. health
if (await gotoOverviewAndStart("Start Health apps declaration")) {
  await mouseCheckbox("My app does not have any health features", "no health features");
  for (let i = 0; i < 3; i++) {
    const nx = await lastBtn("Next");
    if (!nx) break;
    await clickAt(nx, "next");
    await sleep(3000);
  }
  const sv = await lastBtn("Save");
  if (sv) await clickAt(sv, "save health");
  await sleep(3000);
  log("health saved:", await saved());
}

// ---- verify declarations
await page.goto(`${BASE}/app-content/overview`);
await page.waitForLoadState();
await sleep(4500);
log("content tabs:", JSON.stringify(await page.evaluate(() => [...document.querySelectorAll("[role=tab]")].map(t => t.textContent.trim()))));

// ---- 11. store settings
await page.goto(`${BASE}/store-settings`);
await page.waitForLoadState();
await sleep(5000);
{
  const e1 = await page.evaluate(() => {
    const b = [...document.querySelectorAll("button")].filter(x => x.textContent.trim() === "Edit" && x.offsetParent)[0];
    if (!b) return null;
    b.scrollIntoView({ block: "center" });
    const r = b.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  await clickAt(e1, "edit app category");
  await sleep(2000);
  const dd = await page.evaluate(() => {
    const d = [...document.querySelectorAll("material-dropdown-select, [role=combobox]")].filter(x => x.offsetParent && x.textContent.includes("Not selected"))[0];
    if (!d) return null;
    const r = d.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (dd) {
    await clickAt(dd, "open category dropdown");
    await sleep(1200);
    const o = await page.evaluate((cat) => {
      const el = [...document.querySelectorAll("material-select-dropdown-item, [role=option]")].find(x => x.offsetParent && x.textContent.trim() === cat);
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, "__CATEGORY__");
    if (o) { await sleep(300); await clickAt(o, "select __CATEGORY__"); }
    await sleep(900);
    const sv = await lastBtn("Save");
    if (sv) await clickAt(sv, "save category");
    await sleep(2500);
  } else log("category dropdown miss (maybe already set)");
  // close sheet via X if open
  await page.keyboard.press("Escape");
  await sleep(1500);
  // contact details
  const ed = await page.evaluate(() => {
    const out = [];
    for (const e of document.querySelectorAll("*")) {
      if (e.children.length === 0 && e.textContent.trim() === "Edit" && e.offsetParent) {
        const r = e.getBoundingClientRect();
        out.push({ x: r.x + r.width / 2, y: r.y + r.height / 2 });
      }
    }
    return out.pop() || null;
  });
  if (ed) {
    await sleep(300);
    await clickAt(ed, "edit contact details");
    await sleep(2000);
    await sleep(2500);
    const idxs = await page.evaluate(() => [...document.querySelectorAll("input")].map((i, n) => ({ n, vis: !!i.offsetParent, type: i.type, ctx: i.closest("div")?.textContent.trim().slice(0, 30) || "" })).filter(m => m.vis && ["text", "email", "url", "tel", ""].includes(m.type)));
    log("contact inputs:", JSON.stringify(idxs));
    // known-good mapping (moon fix): among visible text inputs, email is the
    // one whose context mentions email (fallback [3]), website shows "https://"
    const mail = idxs.find(m => /email/i.test(m.ctx)) || idxs[3] || idxs[0];
    const web = idxs.find(m => m.ctx.startsWith("https://")) || idxs[5] || idxs[2];
    if (mail) await page.fill(`css=input >> nth=${mail.n}`, "ajijuttam2006@gmail.com");
    if (web) await page.fill(`css=input >> nth=${web.n}`, "imajij.github.io");
    await sleep(700);
    const sv = await lastBtn("Save");
    if (sv) await clickAt(sv, "save contact details");
    await sleep(3000);
    await page.reload();
    await page.waitForLoadState();
    await sleep(4000);
    log("contact verify:", await page.evaluate(() => ({
      email: document.body.innerText.includes("ajijuttam2006@gmail.com"),
      site: document.body.innerText.includes("imajij.github.io"),
    })).then(JSON.stringify));
  } else log("contact edit miss");
}

// ---- 12. store listing
await page.goto(`${BASE}/store-listings`);
await page.waitForLoadState();
await sleep(4500);
{
  const cr = await page.evaluate(() => {
    const el = [...document.querySelectorAll("button, a")].find(x => x.offsetParent && x.textContent.trim() === "Create default store listing");
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (cr) { await clickAt(cr, "create default store listing"); await sleep(6000); }
  else {
    await page.goto(`${BASE}/store-listings/default/edit`);
    await page.waitForLoadState();
    await sleep(5000);
  }
  await page.fill("css=input[type=text] >> nth=1", "__SHORT__");
  await page.fill("css=textarea >> nth=0", `__FULL__`);
  await sleep(700);
  // uploads per slot: icon, feature graphic, phone screenshots
  const slotUpload = async (section, files) => {
    const findAdd = () => page.evaluate((sec) => {
      const adds = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Add assets");
      for (const a of adds) {
        let el = a;
        for (let k = 0; k < 14 && el.parentElement; k++) {
          el = el.parentElement;
          if (el.textContent.replace(/\s+/g, " ").includes(sec)) {
            a.scrollIntoView({ block: "center" });
            const r = a.getBoundingClientRect();
            return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
          }
        }
      }
      return null;
    }, section);
    let p = await findAdd();
    if (!p) { log("slot miss", section); return; }
    await sleep(500);
    p = await findAdd();
    await page.mouse.click(p.x, p.y, { label: "add assets " + section.slice(0, 14) });
    await sleep(2500);
    const chooserP = page.waitForFileChooser({ timeout: 10000 });
    const up = await page.evaluate(() => {
      const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Upload" && e.offsetParent).pop();
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (!up) { log("upload btn miss", section); return; }
    await page.mouse.click(up.x, up.y, { label: "upload files" });
    try {
      const chooser = await chooserP;
      await chooser.setFiles(files);
      await sleep(9000);
      log("uploaded", section, files.length);
    } catch (e) { log("chooser fail", section, e.message.slice(0, 40)); }
    // if an Add button is enabled in panel (library selection flow), click it
    await page.evaluate(() => {
      const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Add" && e.offsetParent).pop();
      if (el && el.closest("button") && !el.closest("button").disabled) el.closest("button").click();
    });
    await sleep(2500);
    // close side panel
    const x = await page.evaluate(() => {
      const el = [...document.querySelectorAll("button")].find(b => b.offsetParent && b.textContent.trim() === "close");
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (x) { await page.mouse.click(x.x, x.y, { label: "close panel" }); await sleep(1500); }
  };
  const shots = [];
  for (let i = 1; i <= __NSHOTS__; i++) shots.push(`${MDIR}/screenshots/0${i}.png`);
  await slotUpload("App icon *", [`${MDIR}/icon-512.png`]);
  await slotUpload("Feature graphic *", [`${MDIR}/feature-graphic.png`]);
  await slotUpload("Phone screenshots *", shots);
  // ensure feature graphic attached (upload sometimes lands only in library)
  {
    const fgState = await page.evaluate(() => {
      const t = document.body.innerText.replace(/\s+/g, " ");
      const i = t.indexOf("Feature graphic *");
      return t.slice(i, i + 320).includes("1 / 1");
    });
    if (!fgState) {
      log("fg fallback: selecting from library");
      const findFg = () => page.evaluate(() => {
        const adds = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Add assets" && e.offsetParent);
        for (const a of adds) {
          let el = a, hit = false;
          for (let k = 0; k < 14 && el.parentElement; k++) {
            el = el.parentElement;
            const t = el.textContent.replace(/\s+/g, " ");
            if (t.includes("Feature graphic *") && !t.includes("App icon")) { hit = true; break; }
          }
          if (hit) { a.scrollIntoView({ block: "center" }); const r = a.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }
        }
        return null;
      });
      let p0 = await findFg();
      if (p0) {
        await sleep(500);
        p0 = await findFg();
        await clickAt(p0, "open fg slot");
        await sleep(2500);
        const row = await page.evaluate(() => {
          const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "feature-graphic.png").pop();
          if (!el) return null;
          const r = el.getBoundingClientRect();
          return { x: r.x - 40, y: r.y + r.height / 2 };
        });
        if (row) { await clickAt(row, "select fg"); await sleep(1200); }
        const add = await page.evaluate(() => {
          const els = [...document.querySelectorAll("button, *")].filter(e => e.offsetParent && e.textContent.trim().replace(/\s+/g, "") === "Add");
          const el = els.pop();
          if (!el) return null;
          const r = el.getBoundingClientRect();
          return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
        });
        if (add) { await clickAt(add, "add fg"); await sleep(2500); }
        await page.keyboard.press("Escape");
        await sleep(1200);
      }
    }
  }
  // save listing
  const nx = await lastBtn("Next");
  if (nx) { await clickAt(nx, "next"); await sleep(4000); }
  const sv = await lastBtn("Save");
  if (sv) { await clickAt(sv, "save listing"); await sleep(5000); }
  log("listing phase done, url:", await page.url());
}

// ---- 13. closed testing release
await page.goto(`${BASE}/closed-testing`);
await page.waitForLoadState();
await sleep(5000);
await clickBtn("Manage track", "manage closed track");
await sleep(5000);
{
  const cnr = await lastBtn("Create new release");
  if (cnr) { await clickBtn("Create new release", "create new release"); }
  else {
    const er = await page.evaluate(() => {
      const el = [...document.querySelectorAll("a, button")].find(x => x.offsetParent && x.textContent.trim() === "Edit release");
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (er) { await sleep(300); await clickAt(er, "edit draft release"); }
    else log("no create/edit release control");
  }
}
for (let i = 0; i < 10; i++) { const b = await page.evaluate(() => [...document.querySelectorAll("button")].some(x => x.offsetParent && x.textContent.replace(/\s+/g, "") === "uploadUpload")); if (b) break; await sleep(3000); }
{
  const chooserP = page.waitForFileChooser({ timeout: 12000 });
  const up = await page.evaluate(() => {
    const b = [...document.querySelectorAll("button")].find(x => x.offsetParent && x.textContent.replace(/\s+/g, "") === "uploadUpload");
    if (!b) return null;
    b.scrollIntoView({ block: "center" });
    const r = b.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (up) {
    await page.mouse.click(up.x, up.y, { label: "upload app bundle" });
    const chooser = await chooserP;
    await chooser.setFiles(["__AAB__"]);
    log("aab upload started");
    for (let i = 0; i < 50; i++) {
      await sleep(6000);
      const st = await page.evaluate(() => {
        const t = document.body.innerText.replace(/\s+/g, " ");
        if (t.includes("Uploading")) return "uploading";
        if (t.match(/1 \(1\.0\.0\)/)) return "DONE";
        const err = t.match(/(error|failed)[^.]{0,60}/i);
        if (err) return "ERR " + err[0];
        return "waiting";
      });
      if (st === "DONE" || st.startsWith("ERR")) { log("aab:", st); break; }
      if (i % 5 === 0) log("aab:", st, i);
    }
  } else log("aab upload btn miss");
  await page.fill("css=textarea >> nth=0", "<en-US>\n__NOTES__\n</en-US>");
  await sleep(700);
  const nx = await lastBtn("Next");
  if (nx) { await clickAt(nx, "review release"); await sleep(6000); }
  log("release review url:", await page.url());
}
// countries
{
  const a = await page.evaluate(() => {
    const el = [...document.querySelectorAll("a, button")].find(x => x.offsetParent && x.textContent.trim() === "Add countries / regions");
    if (!el) return null;
    el.scrollIntoView({ block: "center" });
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (a) {
    await clickAt(a, "add countries");
    await sleep(4500);
    // second click opens the editor table on the tab page
    const a2 = await page.evaluate(() => {
      const el = [...document.querySelectorAll("a, button")].find(x => x.offsetParent && x.textContent.trim() === "Add countries / regions");
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    if (a2) { await clickAt(a2, "open countries editor"); await sleep(3000); }
    const hd = await page.evaluate(() => {
      const cell = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Country / region").pop();
      if (!cell) return null;
      cell.scrollIntoView({ block: "center" });
      const r = cell.getBoundingClientRect();
      return { x: r.x - 80, y: r.y + r.height / 2 };
    });
    if (hd) { await clickAt(hd, "select all countries"); await sleep(1500); }
    const sv = await lastBtn("Save");
    if (sv) { await clickAt(sv, "save countries"); await sleep(4000); }
    log("countries:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/Targeted \(\d+\)|countries \/ regions \(\d+\)/)?.[0]));
  } else log("countries link miss (maybe already targeted)");
}
// testers
{
  const t = await page.evaluate(() => {
    const els = [...document.querySelectorAll("*")].filter(x => x.offsetParent && x.children.length === 0 && x.textContent.trim() === "Testers");
    const el = els.find(x => { const r = x.getBoundingClientRect(); return r.height > 5 && r.height < 60 && r.y > 150; });
    if (!el) return null;
    el.scrollIntoView({ block: "center" });
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (t) {
    await sleep(400);
    const t2c = await page.evaluate(() => {
      const els = [...document.querySelectorAll("*")].filter(x => x.offsetParent && x.children.length === 0 && x.textContent.trim() === "Testers");
      const el = els.find(x => { const r = x.getBoundingClientRect(); return r.height > 5 && r.height < 60 && r.y > 150; });
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    await clickAt(t2c, "open testers tab");
    await sleep(3500);
    const row = await page.evaluate(() => {
      const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Zintara testers" && e.offsetParent).pop();
      if (!el) return null;
      el.scrollIntoView({ block: "center" });
      const r = el.getBoundingClientRect();
      return { x: r.x - 78, y: r.y + r.height / 2 };
    });
    log("tester row:", JSON.stringify(row));
    if (row) {
      await sleep(400);
      const row2 = await page.evaluate(() => {
        const el = [...document.querySelectorAll("*")].filter(e => e.children.length === 0 && e.textContent.trim() === "Zintara testers" && e.offsetParent).pop();
        const r = el.getBoundingClientRect();
        return { x: r.x - 78, y: r.y + r.height / 2 };
      });
      await clickAt(row2, "check Zintara testers");
    }
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
    const sv = await lastBtn("Save");
    if (sv) { await clickAt(sv, "save testers"); await sleep(3500); }
    log("track progress:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/\d of 4 complete/)?.[0]));
  } else log("testers tab miss");
}
// finalize release
{
  const rl = await page.evaluate(() => {
    const el = [...document.querySelectorAll("a, button, div")].find(x => x.offsetParent && /Preview and confirm the release/.test(x.textContent) && x.textContent.length < 60);
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (rl) { await clickAt(rl, "preview and confirm release"); await sleep(6000); }
  log("review errors:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/\d Errors?|\d Warnings?/g)?.slice(0, 3)));
  const sv = await lastBtn("Save");
  if (sv) { await clickAt(sv, "save release"); await sleep(5000); }
  // dismiss "go to publishing overview?" dialog with Not now
  await page.evaluate(() => {
    const d = document.querySelector("[role=dialog]");
    const b = d && [...d.querySelectorAll("button")].find(x => x.textContent.trim() === "Not now");
    b?.click();
  });
  log("release saved, url:", await page.url());
}
log("=== APP DRIVER COMPLETE ===");

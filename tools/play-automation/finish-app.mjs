// finish one app: contact details fix -> release save -> submit
// env-free: APPID/TRACK/NAME substituted by sed
const APPID = "__APPID__";
const TRACK = "__TRACK__";
const task = await taskSpace(12);
const page = task.page("p1");
const sleep = (ms) => page.waitForTimeout(ms);
const log = (...a) => console.log("[finish-__NAME__]", ...a);

// --- contact details
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/store-settings`);
await page.waitForLoadState();
await sleep(7000);
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
  await page.mouse.click(ed.x, ed.y, { label: "edit contact details" });
  let idxs = [];
  for (let i = 0; i < 8 && idxs.length < 3; i++) {
    await sleep(1500);
    idxs = await page.evaluate(() => [...document.querySelectorAll("input")].map((inp, n) => ({ n, vis: !!inp.offsetParent, type: inp.type, ctx: (inp.closest("div")?.textContent.trim().slice(0, 30)) || "" })).filter(m => m.vis && ["text","email","url","tel",""].includes(m.type)));
  }
  log("contact inputs:", JSON.stringify(idxs));
  const mail = idxs.find(m => /email/i.test(m.ctx) || m.type === "email") || idxs[3] || idxs[0];
  const web = idxs.find(m => m.ctx.startsWith("https://") || m.type === "url") || idxs[5] || idxs[2];
  if (mail) await page.fill(`css=input >> nth=${mail.n}`, "ajijuttam2006@gmail.com");
  if (web) await page.fill(`css=input >> nth=${web.n}`, "imajij.github.io");
  await sleep(600);
  const sv = await page.evaluate(() => {
    const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === "Save" && !x.disabled).pop();
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (sv) { await page.mouse.click(sv.x, sv.y, { label: "save contact" }); await sleep(3500); }
  await page.reload();
  await page.waitForLoadState();
  await sleep(5000);
  log("contact verify:", await page.evaluate(() => JSON.stringify({
    email: document.body.innerText.includes("ajijuttam2006@gmail.com"),
    site: document.body.innerText.includes("imajij.github.io"),
  })));
} else log("contact edit MISS");

// --- release save
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/tracks/${TRACK}/releases/1/review`);
await page.waitForLoadState();
await sleep(7000);
log("review flags:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").match(/\d Errors?|\d Warnings?/g)?.slice(0, 3)));
const rsv = await page.evaluate(() => {
  const el = [...document.querySelectorAll("button")].filter(x => x.offsetParent && x.textContent.trim() === "Save" && !x.disabled).pop();
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
});
if (rsv) { await page.mouse.click(rsv.x, rsv.y, { label: "save release" }); await sleep(5500); }
await page.evaluate(() => {
  const d = document.querySelector("[role=dialog]");
  const b = d && [...d.querySelectorAll("button")].find(x => x.textContent.trim() === "Not now");
  b?.click();
});
await sleep(1500);

// --- submit (patient: wait for button up to 45s)
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/publishing`);
await page.waitForLoadState();
let btn = null;
for (let i = 0; i < 15 && !btn; i++) {
  await sleep(3000);
  btn = await page.evaluate(() => {
    const el = [...document.querySelectorAll("button, [role=button]")].find(x => x.offsetParent && /(Submit \d+ changes? for review|Send app for review|Send \d+ changes for review)/.test(x.textContent.trim()) && !x.disabled);
    if (!el) return null;
    el.scrollIntoView({ block: "center" });
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2, t: el.textContent.trim() };
  });
}
log("submit btn:", JSON.stringify(btn));
if (!btn) {
  log("page tail:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").slice(0, 500)));
  process.exit(0);
}
await page.mouse.click(btn.x, btn.y, { label: "send for review" });
await sleep(3500);
const confirm = await page.evaluate(() => {
  const d = document.querySelector("[role=dialog], material-dialog");
  const el = d && [...d.querySelectorAll("button, [role=button]")].find(x => x.offsetParent && /(Send|Submit)/.test(x.textContent.trim()) && !/Cancel/.test(x.textContent));
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2, t: el.textContent.trim() };
});
log("confirm:", JSON.stringify(confirm));
if (confirm) { await page.mouse.click(confirm.x, confirm.y, { label: "confirm send" }); await sleep(6000); }
log("final:", await page.evaluate(() => JSON.stringify({
  inReview: document.body.innerText.match(/Changes in review[^.]{0,20}/)?.[0],
  notYet: document.body.innerText.match(/Changes not yet submitted[^.]{0,20}/)?.[0],
})));

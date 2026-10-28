const APPID = "__APPID__";
const task = await taskSpace(12);
const page = task.page("p1");
const sleep = (ms) => page.waitForTimeout(ms);
const log = (...a) => console.log("[submit-__NAME__]", ...a);
await page.goto(`https://play.google.com/console/u/1/developers/6311775868837893862/app/${APPID}/publishing`);
await page.waitForLoadState();
await sleep(6000);
const btn = await page.evaluate(() => {
  const el = [...document.querySelectorAll("button, [role=button]")].find(x => x.offsetParent && /(Submit \d+ changes? for review|Send app for review|Send \d+ changes for review)/.test(x.textContent.trim()) && !x.disabled);
  if (!el) return null;
  el.scrollIntoView({ block: "center" });
  const r = el.getBoundingClientRect();
  return { x: r.x + r.width / 2, y: r.y + r.height / 2, t: el.textContent.trim() };
});
log("submit btn:", JSON.stringify(btn));
if (!btn) {
  log("page:", await page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").slice(0, 400)));
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
  inReview: document.body.innerText.match(/Changes in review[^.]{0,30}/)?.[0],
  notYet: document.body.innerText.match(/Changes not yet submitted[^.]{0,30}/)?.[0],
})));

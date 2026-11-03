// LuaPad 2.0 preview structural package checks (not an in-game runtime test).
const fs = require("fs");
const path = require("path");
const root = __dirname;
let failures = 0;
function check(label, condition) {
  const ok = !!condition;
  process.stdout.write((ok ? "PASS " : "FAIL ") + label + "\n");
  if (!ok) failures++;
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }
function tocInfo(rel, expectedId) {
  const text = read(rel);
  const folder = path.dirname(rel);
  const identifier = text.match(/^Identifier\s*=\s*"([^"]+)"/m)?.[1];
  const scriptsSection = text.match(/RunOnStartup\s*=\s*\{([\s\S]*?)\}/)?.[1] || "";
  const scripts = [...scriptsSection.matchAll(/"([^"]+\.lua)"/g)].map(m => m[1]);
  check(rel + " identifier", identifier === expectedId);
  check(rel + " metadata", /Email\s*=\s*"[^"]+"/.test(text) && /Environment\s*=\s*"4\.4"/.test(text));
  check(rel + " scripts exist", scripts.length > 0 && scripts.every(s => fs.existsSync(path.join(root,folder,s))));
  check(rel + " script names unique", new Set(scripts).size === scripts.length);
}
tocInfo("RiftAddon.toc", "LuaPad");
tocInfo("Inspector/RiftAddon.toc", "Inspector");
tocInfo("LibSimpleWidgets/RiftAddon.toc", "LibSimpleWidgets");
const main = read("main.lua");
const inspector = read("Inspector/main.lua");
const widgets = read("LibSimpleWidgets/uicreateframe.lua");
const scroll = read("LibSimpleWidgets/scrollview.lua");
const window = read("LibSimpleWidgets/window.lua");
check("LuaPad preview version", /Version\s*=\s*"2\.0\.0-preview1"/.test(read("RiftAddon.toc")));
check("Direct widget construction", main.includes("Library.LibSimpleWidgets.Window") && main.includes("Library.LibSimpleWidgets.ScrollView") && inspector.includes("Library.LibSimpleWidgets.Window"));
check("No global UI.CreateFrame override", !/UI\.CreateFrame\s*=/.test(widgets));
check("No legacy RiftButton constructors", ![main, inspector].some(x => /UI\.CreateFrame\("RiftButton"/.test(x)));
check("Protected code execution", main.includes("pcall(loader, obj)") && main.includes("xpcall(compiled") && main.includes("print = origPrint"));
check("Protected inspection", inspector.includes("pcall(loader, 'return ' .. obj)") && inspector.includes("pcall(compiled)") && inspector.includes("inspectionNodeCount > 300"));
check("Modern text and slider events", main.includes("Event.UI.Textfield.Change") && inspector.includes("Event.UI.Slider.Change"));
check("Modern scroll events", scroll.includes("Event.UI.Layout.Size") && scroll.includes("wheel.Forward") && scroll.includes("wheel.Back"));
check("No full-window drag overlay", !window.includes("SetAllPoints(window)"));
check("Guarded installer exists", fs.existsSync(path.join(root,"install-preview.ps1")));
process.stdout.write("\n" + (failures ? failures + " failed" : "All structural checks passed") + "\n");
process.exitCode = failures ? 1 : 0;

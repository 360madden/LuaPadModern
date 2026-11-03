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
check("LuaPad preview version", /Version\s*=\s*"2\.0\.0-preview7"/.test(read("RiftAddon.toc")));
check("Direct widget construction", main.includes("Library.LibSimpleWidgets.Window") && main.includes("Library.LibSimpleWidgets.ScrollView") && inspector.includes("Library.LibSimpleWidgets.Window"));
check("No global UI.CreateFrame override", !/UI\.CreateFrame\s*=/.test(widgets));
check("No legacy RiftButton constructors", ![main, inspector].some(x => /UI\.CreateFrame\("RiftButton"/.test(x)));
check("Protected code execution", main.includes("pcall(loader, obj)") && main.includes("xpcall(compiled") && main.includes("print = origPrint"));
check("Protected inspection", inspector.includes('pcall(loader, "return " .. expression)') && inspector.includes("pcall(compiled)") && inspector.includes("nodes > MAX_NODES"));
check("Modern text and slider events", main.includes("Event.UI.Textfield.Change") && inspector.includes("Event.UI.Slider.Change"));
check("Scroll view handles empty and exact-fit content", scroll.includes("math.max(0, self.content:GetHeight() - self:GetHeight())") && (scroll.match(/self.content:GetHeight\(\) <= self:GetHeight\(\)/g) || []).length === 3);
check("Harness executes real scroll view source", read("inspector-runtime-tests.lua").includes('loadfile("LibSimpleWidgets/scrollview.lua")'));
check("Modern scroll events", scroll.includes("Event.UI.Layout.Size") && scroll.includes("wheel.Forward") && scroll.includes("wheel.Back"));
check("No full-window drag overlay", !window.includes("SetAllPoints(window)"));
check("LuaPad output text wraps and grows", main.includes("outputField:SetWordwrap(true)") && main.includes("local visualLines = 0") && main.includes("setOutput(combined)"));
check("Runtime harness covers root LuaPad and Inspector", read("inspector-runtime-tests.lua").includes('loadfile("main.lua")') && read("inspector-runtime-tests.lua").includes("LuaPad output wraps long lines"));
check("Native clipboard output button", main.includes("LuaPadCopyOutputButton") && main.includes("pcall(Command.CopyToClipboard, content)"));
check("Metadata-driven title", main.includes("Inspect.Addon.Detail") && main.includes("detail.toc.Version") && main.includes('"LuaPad v" .. currentVersion()'));
check("Chat startup confirmation", main.includes('READY - type /lp to open') && main.includes('Loaded with UI errors'));
check("Unified 7-button toolbar", main.includes('{ copyOutputButton, "Copy Output", 112 }') && main.includes("toolbarX = toolbarX + width + 5") && main.includes('toolbarX, 48'));
check("Section labels aligned", main.includes('label3:SetPoint("TOPLEFT", luaPadWindow, "TOPLEFT", 554, 48)') && (main.match(/SetFontColor\(0\.73,0\.88,0\.92,1\)/g) || []).length === 3);
check("Inspector version source of truth", /Version\s*=\s*"1\.9\.0-preview2"/.test(read("Inspector/RiftAddon.toc")) && inspector.includes('detail.toc.Version') && inspector.includes('textWindow:SetTitle("Inspector v" .. currentVersion())'));
check("Inspector startup confirmation", inspector.includes('READY - type /ti to open'));
check("Inspector scrollable read-only results", inspector.includes('Library.LibSimpleWidgets.ScrollView("InspectorOutputScroll"') && inspector.includes('outputScroll:SetContent(outputText)') && inspector.includes('local lastOutput = ""'));
check("Inspector clipboard API", inspector.includes('pcall(Command.CopyToClipboard, lastOutput)'));
check("Inspector compact help window", inspector.includes('helpWindow:SetWidth(650); helpWindow:SetHeight(430)') && inspector.includes('helpText:SetWidth(602); helpText:SetHeight(290)'));
check("Inspector direct 1 to 5 depth", inspector.includes('depthSlider:SetRange(1, 5)') && inspector.includes('depthSlider:SetPosition(1)') && !inspector.includes('5 - depthSlider:GetPosition()'));
check("Inspector true-cycle tracking", inspector.includes('visiting[value] = true') && inspector.includes('visiting[value] = nil') && !inspector.includes('temporaryTableDetails[tostring(obj)]'));
check("Inspector bounded sorted traversal", inspector.includes('local MAX_NODES, MAX_CHARS = 300, 12000') && inspector.includes('table.sort(keys, function(a, b)'));
check("Inspector errors always visible", inspector.includes('displayOutput("Syntax error: "') && inspector.includes('displayOutput("Inspection error: "') && inspector.includes('displayOutput("Table traversal error: "'));
check("Inspector button uses numeric slider position", inspector.includes("Inspector.doInspection(inputField:GetText(), depthSlider:GetPosition())") && !inspector.includes("tonumber(depthText:GetText())"));
check("Inspector button handler errors copyable", inspector.includes("if reportButtonError then pcall(reportButtonError, message) end") && inspector.includes("reportButtonError = function(message) displayOutput(message) end"));
check("Inspector runtime harness present", fs.existsSync(path.join(root, "inspector-runtime-tests.lua")));
check("Inspector aligned modern actions", inspector.includes('item[1]:SetPoint("TOPLEFT", textWindow, "TOPLEFT", x, 544)') && inspector.includes('name .. "Edge" .. i'));
check("Guarded installer exists", fs.existsSync(path.join(root,"install-preview.ps1")));
process.stdout.write("\n" + (failures ? failures + " failed" : "All structural checks passed") + "\n");
process.exitCode = failures ? 1 : 0;

/** Runs inside an isolated Pi process: real SDK components, no model or tools executed. */
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ToolExecutionComponent, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Container, visibleWidth } from "@earendil-works/pi-tui";
import claudeUi from "../node_modules/pi-claude-code-ui/precompiled/index.js";

export default function (pi: ExtensionAPI) {
	const definitions = new Map();
	const hooks = new Map<string, Function[]>();
	claudeUi({
		...pi,
		registerTool(definition: any) {
			definitions.set(definition.name, definition);
			pi.registerTool(definition);
		},
		on(event: string, handler: Function) {
			hooks.set(event, [...(hooks.get(event) ?? []), handler]);
			(pi.on as any)(event, handler);
		},
	});
	pi.on("session_start", async (_event, ctx) => {
		try {
			let cases = 0;
			let nextId = 0;
			const realNow = Date.now;
			let clockOffset = 0;
			Date.now = () => realNow() + clockOffset;
			const setSettings = (overrides = {}) => {
				const dir = join(process.env.HOME!, ".pi");
				mkdirSync(dir, { recursive: true });
				writeFileSync(join(dir, "settings.json"), JSON.stringify({ toolBackground: "border", groupToolCalls: true, ...overrides }));
				clockOffset += 6000; // expire the upstream settings cache without sleeping
			};
			setSettings();
			const result = (text: string, isError = false, details: any = {}) => ({ content: [{ type: "text", text }], isError, details });
			const make = (name: string, args: any, output: any, partial = false) => {
				const tool = new ToolExecutionComponent(name, `synthetic-${nextId++}`, args, { showImages: false }, definitions.get(name), { requestRender() {} } as any, process.cwd());
				tool.setArgsComplete();
				tool.markExecutionStarted();
				tool.updateResult(output, partial);
				return tool;
			};
			const render = (component: any, width = 100) => {
				const rows = component.render(width);
				assert.ok(rows.every((line: string) => visibleWidth(line) <= width), `overflow at width ${width}`);
				return rows.join("\n").replace(/\x1b\[[0-9;]*m/g, "");
			};
			const check = (name: string, fn: () => void) => {
				try { fn(); cases++; } catch (error) { throw new Error(name, { cause: error }); }
			};
			const log = Array.from({ length: 30 }, (_, i) => `output-${String(i + 1).padStart(2, "0")}`).join("\n");
			const bash = make("bash", { command: "printf synthetic" }, result(log));
			check("head/tail and expanded output", () => {
				const text = render(bash);
				for (const value of ["printf synthetic", "output-01", "output-03", "24 lines hidden", "output-28", "output-30"]) assert.ok(text.includes(value), value);
				assert.ok(!text.includes("output-04"));
				bash.setExpanded(true);
				assert.ok(render(bash).includes("output-15"));
				bash.setExpanded(false);
			});
			check("one-line results and targets for builtins/custom/MCP", () => {
				for (const [name, args, target] of [
					["read", { path: "sample.txt" }, "sample.txt"],
					["grep", { pattern: "needle", path: "src" }, "needle"],
					["find", { pattern: "*.ts" }, "*.ts"],
					["ls", { path: "src" }, "src"],
					["mcp", { tool: "example.status" }, "example.status"],
					["mcp_example_status", { file: "sample.txt" }, "Mcp Example Status"],
					["example_read", { file: "sample.txt", token: "DO-NOT-DISPLAY" }, "sample.txt"],
				] as const) {
					const text = render(make(name, args, result("single-result-line\n")));
					assert.ok(text.includes("single-result-line"), name);
					assert.ok(text.includes(target), name);
					assert.ok(!text.includes("DO-NOT-DISPLAY"));
				}
			});
			check("failure status and larger tail, including timeout and edit failure", () => {
				const failure = make("bash", { command: "synthetic failure" }, result(`${log}\nCommand exited with code 7`, true));
				const text = render(failure);
				assert.ok(text.includes("Exit 7"));
				assert.ok(text.includes("output-20"));
				assert.ok(!text.includes("output-19"));
				assert.ok(render(make("bash", { command: "synthetic timeout" }, result("Command timed out after 10 seconds", true))).includes("Failed"));
				assert.ok(render(make("edit", { path: "sample.txt", edits: [] }, result(log, true))).includes("output-20"));
			});
			check("groups preserve repeated results and failed calls", () => {
				const group = new Container();
				group.addChild(make("bash", { command: "same command" }, result("first-result")));
				group.addChild(make("bash", { command: "same command" }, result(`${log}\nCommand exited with code 9`, true)));
				assert.equal(group.children.length, 1, "fixture must actually group calls");
				const text = render(group, 120);
				for (const value of ["first-result", "Exit 9", "output-20", "same command"]) assert.ok(text.includes(value), value);
				assert.equal((text.match(/same command/g) ?? []).length, 2);
				for (const width of [12, 40, 80]) render(group, width);
			});
			check("completed command blocks and skill paths remain visible", () => {
				const text = render(make("bash", { command: "cd project\nprintf synthetic" }, result("ok")));
				assert.ok(text.includes("cd project"));
				assert.ok(text.includes("printf synthetic"));
				assert.ok(render(make("read", { path: "/synthetic/skills/demo/SKILL.md" }, result("skill body"))).includes("SKILL.md"));
			});
			check("partial-to-final and following activity do not release previews", () => {
				const tool = make("bash", { command: "synthetic stream" }, result("partial-output"), true);
				assert.ok(render(tool).includes("partial-output"));
				tool.updateResult(result("settled-output"), false);
				for (const handler of hooks.get("tool_execution_start") ?? []) handler({ toolName: "read", toolCallId: "later", args: {} }, ctx);
				for (const handler of hooks.get("message_update") ?? []) handler({ message: { content: [{ type: "text", text: "later response" }] } }, ctx);
				tool.invalidate();
				assert.ok(render(tool).includes("settled-output"));
				assert.ok(render(make("bash", { command: "synthetic stream" }, result("settled-output"))).includes("settled-output"), "reconstructed history");
			});
			check("truncation is explicit and stored results are unchanged", () => {
				const output = result(log, false, { truncation: { truncated: true } });
				const before = JSON.stringify(output);
				const tool = make("bash", { command: "synthetic truncated" }, output);
				assert.ok(render(tool, 140).includes("tool output truncated; preview uses returned output"));
				assert.equal(JSON.stringify(output), before);
			});
			check("long lines are clipped, ANSI and narrow widths are safe", () => {
				const tool = make("bash", { command: "synthetic wide" }, result(`\x1b[31m${"wide ".repeat(500)}\x1b[0m`));
				for (const width of [12, 40, 80, 160]) {
					const text = render(tool, width);
					assert.ok(text.split("\n").length < 20);
				}
			});
			check("settings alter previews and expansion remains separately capped", () => {
				setSettings({ outputPreviewFullLines: 2, outputPreviewHeadLines: 1, outputPreviewTailLines: 1, expandedPreviewMaxLines: 5 });
				const tool = make("bash", { command: "synthetic custom" }, result(log));
				assert.ok(render(tool).includes("28 lines hidden"));
				assert.ok(!render(tool).includes("output-02"));
				tool.setExpanded(true);
				assert.ok(render(tool).includes("output-05"));
				assert.ok(!render(tool).includes("output-06"));
			});
			check("opt-outs retain upstream behavior without hiding failures", () => {
				setSettings({ completedToolPreview: false, bashAlwaysShowCommand: false, liveToolPreview: false, mcpOutputMode: "hidden" });
				assert.ok(!render(make("read", { path: "sample.txt" }, result("hidden-success"))).includes("hidden-success"));
				assert.ok(!render(make("mcp", { tool: "example.status" }, result("hidden-success"))).includes("hidden-success"));
				assert.ok(render(make("mcp", { tool: "example.status" }, result("visible-failure", true))).includes("visible-failure"));
				const group = new Container();
				group.addChild(make("bash", { command: "same" }, result("hidden-success")));
				group.addChild(make("bash", { command: "same" }, result("visible-failure", true)));
				assert.ok(render(group).includes("visible-failure"));
			});
			check("empty results and disabled grouping", () => {
				setSettings({ groupToolCalls: false });
				const group = new Container();
				group.addChild(make("bash", { command: "synthetic empty" }, result("")));
				group.addChild(make("bash", { command: "synthetic empty failure" }, result("", true)));
				assert.equal(group.children.length, 2);
				const text = render(group);
				assert.ok(text.includes("Done (0 lines) (no output)"));
				assert.ok(text.includes("Failed (0 lines) (no output)"));
			});
			check("successful diffs and images retain their specialized rendering", () => {
				setSettings();
				const edit = make("edit", { path: "sample.txt", edits: [] }, result("do-not-replace-diff", false, { _type: "editInfo", added: 1, removed: 0, hunks: 1, editLine: 2 }));
				assert.ok(!render(edit).includes("do-not-replace-diff"));
				const image = make("read", { path: "sample.png" }, { content: [{ type: "image", data: "", mimeType: "image/png" }], isError: false });
				assert.ok(!render(image).includes("Done (0 lines)"));
			});
			writeFileSync(join(process.env.HOME!, "renderer-smoke-passed"), `${cases}\n`);
			console.log(`Claude UI renderer: ${cases} synthetic scenarios passed`);
			process.exit(0);
		} catch (error) {
			console.error(error);
			process.exit(1);
		}
	});
}

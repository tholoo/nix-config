/** Real Pi renderers and built-in Mermaid transformer; no provider or live session. */
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";
import {
	AssistantMessageComponent, InteractiveMode, SettingsManager, UserMessageComponent,
	getMarkdownTheme, type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import claudeUi from "../node_modules/pi-claude-code-ui/precompiled/index.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => {
		const failures: string[] = [];
		let cases = 0;
		const check = (name: string, fn: () => void) => {
			try { fn(); cases++; } catch (error) { failures.push(`${name}: ${error}`); }
		};
		// Construct, but never start, interactive mode to use Pi's actual transformer.
		const settings = SettingsManager.inMemory();
		const mode = new InteractiveMode({
			session: {
				settingsManager: settings,
				sessionManager: { getCwd: () => process.env.HOME },
				autoCompactionEnabled: false,
				resourceLoader: { getThemes: () => ({ themes: [] }) },
				extensionRunner: { getMarkdownTransformers: () => [] },
			},
			setBeforeSessionInvalidate() {}, setRebindSession() {},
		} as any) as any;
		const nativeTransforms = mode.getMarkdownTransformers();
		const diagram = "```mermaid\nflowchart TD\n    A[Start] --> B[Finish]\n```";
		const message = (text: string, thinking = false) => ({
			role: "assistant", stopReason: "stop",
			content: [thinking ? { type: "thinking", thinking: text } : { type: "text", text }],
		} as any);
		const make = (text: string, transforms = nativeTransforms, thinking = false, streaming = false) => {
			const msg = message(text, thinking);
			const component = new AssistantMessageComponent(undefined, false, getMarkdownTheme(), "Thinking...", 1, transforms);
			component.updateContent(msg, streaming);
			return component;
		};
		const render = (component: any, width = 100) => {
			const rows = component.render(width);
			assert.ok(rows.every((row: string) => visibleWidth(row) <= width), `overflow at ${width} columns`);
			return stripVTControlCharacters(rows.join("\n"));
		};
		check("stock Pi renders Mermaid by default", () => {
			assert.equal(settings.getMermaidRenderingMode(), "streaming");
			assert.ok(!render(make(diagram)).includes("flowchart TD"));
		});
		claudeUi(pi);

		for (const renderingMode of ["off", "final", "streaming"] as const) {
			for (const streaming of [true, false]) {
				check(`Mermaid ${renderingMode}, streaming=${streaming}`, () => {
					settings.setMermaidRenderingMode(renderingMode);
					const output = render(make(diagram, nativeTransforms, false, streaming));
					const shouldRender = renderingMode === "streaming" || (renderingMode === "final" && !streaming);
					assert.equal(!output.includes("flowchart TD"), shouldRender);
					assert.ok(output.includes("Start") && output.includes("Finish"));
				});
			}
		}
		settings.setMermaidRenderingMode("streaming");
		check("streamed final and restored messages use the same pipeline", () => {
			const component = make("```mermaid\nflowchart TD\n A[Start]", nativeTransforms, false, true);
			render(component);
			component.updateContent(message(diagram), false);
			assert.ok(!render(component).includes("flowchart TD"));
			assert.equal(render(component), render(make(diagram)));
		});
		check("arbitrary transforms run once on the whole block before math segmentation", () => {
			const calls: any[] = [];
			const text = "BEFORE\n\n$$\\alpha + \\beta$$\n\nAFTER";
			const component = make(text, [(source: string, context: any) => {
				calls.push({ source, ...context });
				return source.replace("BEFORE", "Transformed heading").replace("AFTER", "Transformed footer");
			}]);
			const output = render(component, 80);
			assert.equal(calls.length, 1);
			assert.deepEqual(calls[0], { source: text, messageType: "assistant", isStreaming: false, availableWidth: 77 });
			for (const part of ["Transformed heading", "Transformed footer", "α", "β"]) assert.ok(output.includes(part), part);
			assert.equal(render(component, 80), output);
			assert.equal(calls.length, 1, "warm renders remain cached");
			render(component, 40);
			assert.equal(calls.at(-1).availableWidth, 37);
			assert.equal(calls.length, 2, "resize re-runs the full pipeline");
		});
		check("transform order, errors, and empty results retain core semantics", () => {
			const transforms = [
				(text: string) => text.replace("RAW", "FIRST"),
				() => { throw new Error("synthetic transformer failure"); },
				(text: string) => text.replace("FIRST", "LAST"),
			];
			assert.ok(render(make("RAW", transforms)).includes("LAST"));
			assert.ok(!render(make("RAW", [() => ""])).includes("RAW"));
		});
		check("thinking retains transformer context and native click-to-collapse", () => {
			const calls: any[] = [];
			const component = make("RAW", [(text: string, context: any) => {
				calls.push(context); return text.replace("RAW", "THOUGHT");
			}], true, true);
			assert.ok(render(component, 80).includes("THOUGHT"));
			assert.deepEqual(calls[0], { messageType: "assistant-thinking", isStreaming: true, availableWidth: 77 });
			component.updateContent(message("RAW", true), false);
			assert.ok(render(component, 80).includes("THOUGHT"));
			assert.equal(calls.at(-1).isStreaming, false);
			const region = (component as any).contentContainer.children.find((child: any) => child.handleMouse);
			assert.ok(region, "native MouseRegion was lost");
			region.handleMouse({ type: "click", button: "left" });
			assert.ok(!render(component, 80).includes("THOUGHT"));
		});
		check("user transforms, invalidation, rebuilding, and list/escape options", () => {
			let label = "FIRST";
			const calls: any[] = [];
			const user = new UserMessageComponent("RAW\n\n7. seventh\n8. eighth\n\npath\\name", getMarkdownTheme(), 1, [
				(text: string, context: any) => { calls.push(context); return text.replace("RAW", label); },
			]);
			assert.ok(render(user, 80).includes("FIRST"));
			assert.deepEqual(calls[0], { messageType: "user", isStreaming: false, availableWidth: 74 });
			label = "SECOND";
			user.invalidate();
			const output = render(user, 80);
			for (const part of ["SECOND", "7.", "8.", "path\\name"]) assert.ok(output.includes(part), part);
			label = "THIRD";
			user.setOutputPad(0);
			assert.ok(render(user, 80).includes("THIRD"));
			assert.equal(calls.at(-1).availableWidth, 76);
		});
		check("assistant invalidation updates transforms without mutating stored text", () => {
			let label = "FIRST";
			const msg = message("RAW");
			const before = JSON.stringify(msg);
			const component = make("RAW", [() => label]);
			component.updateContent(msg, false);
			assert.ok(render(component).includes("FIRST"));
			label = "SECOND";
			component.invalidate();
			assert.ok(render(component).includes("SECOND"));
			assert.equal(JSON.stringify(msg), before);
		});
		check("math formatting leaves literal code from any transformer unchanged", () => {
			const literal = "$\\alpha$ \\(beta\\) $$\\gamma$$";
			for (const code of [
				`\`\`\`text\n${literal}\n\`\`\``,
				`~~~~text\n${literal}\n~~~~~`,
				`\`\`\`text\n${literal}`, // incomplete streaming fence
				`\`${literal}\``,
				`\`\`backtick \` ${literal}\`\``,
				`    ${literal}`,
			]) {
				const output = render(make("RAW", [() => `Math $\\beta$ outside.\n\n${code}\n\n`]), 160);
				assert.ok(output.includes(literal), `literal code changed: ${JSON.stringify(code)}`);
				assert.ok(output.includes("β"), "prose math still renders");
			}
		});
		check("ordinary Markdown, code, inline/display math and narrow widths", () => {
			const text = "# Heading\n\n**Bold** and [Link](https://example.com) with $\\alpha$.\n\n- First\n- Second\n\n| Name | Value |\n| --- | --- |\n| sample | 42 |\n\n```ts\nconst answer = 42;\n```\n\n$$\\beta^2$$\n\n日本語";
			const component = make(text);
			const output = render(component, 100);
			for (const part of ["Heading", "Bold", "Link", "First", "Second", "sample", "42", "const answer", "α", "β", "日本語"]) assert.ok(output.includes(part), part);
			assert.ok(component.render(100).join("\n").includes("https://example.com"), "link destination is preserved, including OSC 8 links");
			for (const width of [0, 1, 3, 12, 40, 80, 160]) render(component, width);
		});
		if (failures.length) {
			console.error(failures.join("\n"));
			process.exit(1);
		}
		writeFileSync(join(process.env.HOME!, "markdown-smoke-passed"), `${cases}\n`);
		console.log(`Claude UI Markdown: ${cases} synthetic scenarios passed`);
		process.exit(0);
	});
}

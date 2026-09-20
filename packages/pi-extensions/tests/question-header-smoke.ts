/** Real question schema and renderers; synthetic answers, no model or live UI. */
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text, visibleWidth } from "@earendil-works/pi-tui";
import { Value } from "typebox/value";
import { registerAskUserQuestionTool } from "../node_modules/@juicesharp/rpiv-ask-user-question/ask-user-question.js";
import { TabBar } from "../node_modules/@juicesharp/rpiv-ask-user-question/view/components/tab-bar.js";
import { QuestionTabStrategy, SubmitTabStrategy } from "../node_modules/@juicesharp/rpiv-ask-user-question/view/tab-content-strategy.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		try {
			let tool: any;
			const events: any[] = [];
			registerAskUserQuestionTool({
				registerTool(definition: any) { tool = definition; },
				on() {},
				events: { emit(name: string, payload: any) { events.push({ name, payload }); } },
			} as any);
			const headers = ["Short", "Exactly 16 chars", "A header longer than sixteen characters", "測試 🧪 e\u0301 ".repeat(200)];
			const params = {
				questions: headers.map((header, index) => ({
					header, question: `Which synthetic option for question ${index + 1}?`,
					options: [{ label: "First", description: "First choice" }, { label: "Second", description: "Second choice" }],
				})),
			};
			const before = JSON.stringify(params);
			assert.ok(Value.Check(tool.parameters, params), "long question headers must pass the registered tool schema");
			assert.equal(tool.parameters.properties.questions.items.properties.header.maxLength, undefined);
			assert.doesNotMatch(tool.parameters.properties.questions.items.properties.header.description, /hard limit|MAX 16/);
			const invalid = (mutate: (p: any) => void) => {
				const copy = structuredClone(params);
				mutate(copy);
				assert.ok(!Value.Check(tool.parameters, copy), "unrelated schema validation must remain enabled");
			};
			invalid(p => { p.questions[0].header = 42; });
			invalid(p => { delete p.questions[0].header; });
			invalid(p => { p.questions.push(p.questions[0]); });
			invalid(p => { p.questions[0].options.pop(); });
			invalid(p => { p.questions[0].options[0].label = "x".repeat(61); });

			const titles: string[] = [];
			const result = await tool.execute("synthetic-header", params, undefined, undefined, {
				mode: "rpc", hasUI: true,
				ui: { async select(title: string, options: string[]) { titles.push(title); return options[0]; }, async input() { return "synthetic"; } },
			});
			assert.equal(result.details.cancelled, false);
			assert.equal(result.details.answers.length, 4);
			assert.equal(titles.length, 4);
			for (let i = 0; i < headers.length; i++) assert.ok(titles[i].includes(headers[i]));
			assert.deepEqual(events.find(e => e.name === "rpiv:ask-user:prompt").payload.questions.map((q: any) => q.header), headers);

			const state: any = { currentTab: 0, answers: new Map(), notesByTab: new Map(), notesVisible: false, inputMode: false };
			const pane: any = new Text("Synthetic options", 0, 0);
			const questionView = new QuestionTabStrategy({
				theme: ctx.ui.theme, questions: params.questions, getPreviewPane: () => pane,
				tabsByIndex: [], notesInput: pane, isMulti: false, getCurrentBodyHeight: () => 1, collapseKey: "off",
			});
			const reviewView = new SubmitTabStrategy({ theme: ctx.ui.theme, questions: params.questions, notesInput: pane, submitPicker: undefined });
			const tabs = new TabBar(ctx.ui.theme);
			for (let i = 0; i < headers.length; i++) {
				state.currentTab = i;
				state.answers.set(i, { kind: "option", answer: "First" });
				tabs.setProps({ tabs: headers.map((label, index) => ({ label, active: i === index, answered: index <= i })), submit: { active: false, allAnswered: false } });
				for (const width of [20, 40, 80, 120]) {
					const components = [tabs, ...questionView.headingRows(state), reviewView.bodyComponent(state)];
					for (const component of components) {
						assert.ok(component.render(width).every((line: string) => visibleWidth(line) <= width), `header overflow at ${width} columns`);
					}
				}
			}
			assert.equal(JSON.stringify(params), before, "rendering and execution must preserve full headers");
			writeFileSync(join(process.env.HOME!, "question-header-smoke-passed"), "passed\n");
			console.log("PASS: long headers accepted; schema safeguards, RPC headers and narrow/Unicode rendering preserved");
		} catch (error) {
			console.error(error);
			process.exitCode = 1;
		} finally {
			ctx.shutdown();
		}
	});
}

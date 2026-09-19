/** Exercise the compiled spinner with synthetic events and Pi's real Loader. */
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Loader } from "@earendil-works/pi-tui";
import spinner from "../node_modules/pi-claude-code-ui/precompiled/spinner.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async () => {
		const hooks = new Map<string, Function[]>();
		spinner({
			on(event: string, handler: Function) {
				hooks.set(event, [...(hooks.get(event) ?? []), handler]);
			},
			getThinkingLevel: () => "high",
		});
		const realNow = Date.now;
		let now = 100_000;
		Date.now = () => now;
		let message: string | undefined;
		const ctx = { hasUI: true, ui: { setWorkingMessage(value?: string) { message = value; } } };
		const fire = async (name: string, event = {}) => {
			for (const handler of hooks.get(name) ?? []) await handler(event, ctx);
		};
		const update = (event: object) => fire("message_update", { assistantMessageEvent: event });
		const plain = (value: string) => value.replace(/\x1b\[[0-9;]*m/g, "");
		let loader: Loader | undefined;
		try {
			await fire("turn_start");
			assert.ok(message, "empty visible status must not trigger Pi's default-message fallback");
			assert.equal(plain(message!), "", "no novelty word or ellipsis before stats arrive");
			loader = new Loader({ requestRender() {} } as any, (s) => s, (s) => s, message!);
			const firstFrame = plain(loader.render(100).join("\n")).trim();
			assert.match(firstFrame, /^[·✢*✳✶✻✽]$/u, "glyph remains visible without a word");
			(loader as any).currentFrame++;
			(loader as any).updateDisplay();
			assert.notEqual(plain(loader.render(100).join("\n")).trim(), firstFrame, "glyph still animates");
			loader.stop();

			await update({ type: "thinking_start" });
			assert.equal(plain(message!), "(thinking with high effort · 0s)");
			now += 2_000;
			await update({ type: "text_delta", contentIndex: 0, delta: "x".repeat(40) });
			await update({ type: "thinking_end" });
			assert.equal(plain(message!), "(thought for 2s · ↓ 10 tokens · 2s)");
			await fire("turn_end");
			assert.equal(plain(message!), "✻ Turn took 2s", "completion timing is unchanged");
			await fire("session_shutdown");
			assert.equal(message, undefined, "shutdown restores the default");

			await fire("turn_start");
			now += 31_000;
			await update({ type: "thinking_end" }); // forces a refresh without starting thinking
			assert.equal(plain(message!), "(31s)", "elapsed-only status survives without a verb");
			console.log("Claude UI spinner: glyph, animation, thinking, tokens, elapsed, completion and cleanup passed");
			writeFileSync(join(process.env.HOME!, "spinner-smoke-passed"), "passed\n");
		} finally {
			loader?.stop();
			await fire("session_shutdown");
			Date.now = realNow;
		}
		process.exit(0);
	});
}

/** One native desktop notification per settled interactive response; no OSC/bell. */
import { basename } from "node:path";
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Outcome = "complete" | "error" | undefined;

function projectLabel(cwd: string): string {
	const plain = stripVTControlCharacters(basename(cwd)).replace(/[\p{Cc}\p{Cf}]/gu, "");
	return Array.from(plain || "Workspace").slice(0, 120).join("")
		.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export function registerDesktopNotifications(pi: ExtensionAPI, env: NodeJS.ProcessEnv = process.env) {
	let pending = false;
	let outcome: Outcome;
	const reset = () => { pending = false; outcome = undefined; };
	const eligible = (ctx: ExtensionContext) => {
		const parent = env.PI_SUBAGENT_PARENT_SESSION;
		return ctx.mode === "tui"
			&& !!env.DBUS_SESSION_BUS_ADDRESS
			&& env.PI_SUBAGENT_CHILD !== "1"
			&& env.PI_IS_SUBAGENT !== "1"
			&& (!parent || parent === ctx.sessionManager.getSessionId());
	};

	pi.on("session_start", reset);
	pi.on("session_shutdown", reset);
	pi.on("agent_start", (_event, ctx) => {
		pending = eligible(ctx);
		outcome = undefined;
	});
	pi.on("agent_end", (event, ctx) => {
		if (!pending || !eligible(ctx)) return;
		// Do not announce cancelled runs or tool-only intermediate responses as done.
		const assistant = event.messages.findLast(message => message.role === "assistant");
		outcome = assistant?.stopReason === "error" ? "error"
			: assistant?.stopReason === "stop" || assistant?.stopReason === "length" ? "complete"
			: undefined;
	});
	pi.on("agent_settled", async (_event, ctx) => {
		// Another extension may already have started a continuation by this point.
		if (!pending || !eligible(ctx) || !ctx.isIdle()) return;
		pending = false; // Consume before awaiting, including on delivery failure.
		if (!outcome) return;
		const title = outcome === "error" ? "Pi stopped with an error" : "Pi finished";
		const body = `${projectLabel(ctx.cwd)} — ${outcome === "error" ? "Check the session for details." : "Ready for input."}`;
		try {
			const result = await pi.exec(env.PI_NOTIFY_SEND || "notify-send", [
				"--app-name=Pi", "--icon=dialog-information", "--urgency=normal",
				"--expire-time=8000", "--", title, body,
			], { timeout: 5000 });
			if (result.code !== 0 || result.killed) throw new Error("notification delivery failed");
		} catch {
			// Notification delivery must never fail the agent's completed work.
			ctx.ui.notify("Could not send the Pi desktop notification.", "warning");
		}
	});
}

export default function (pi: ExtensionAPI) {
	registerDesktopNotifications(pi);
}

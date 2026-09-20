/** Notification lifecycle checks in Pi's SDK, without contacting a desktop bus. */
import assert from "node:assert/strict";
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerDesktopNotifications } from "../desktop-notify.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		let passed = 0;
		const fixture = (overrides: Record<string, string | undefined> = {}, mode = "tui") => {
			const hooks = new Map<string, Function>();
			const executions: any[] = [];
			const warnings: string[] = [];
			const env = { DBUS_SESSION_BUS_ADDRESS: "synthetic-bus", PI_NOTIFY_SEND: "/synthetic/bin/notify-send", ...overrides };
			let result: any = { code: 0, killed: false };
			const context: any = {
				mode, cwd: "/projects/fixture", isIdle: () => true,
				sessionManager: { getSessionId: () => "root-fixture" },
				ui: { notify: (message: string) => warnings.push(message) },
			};
			registerDesktopNotifications({
				on(name: string, callback: Function) { hooks.set(name, callback); },
				async exec(command: string, args: string[], options: any) {
					executions.push({ command, args, options });
					if (result instanceof Error) throw result;
					return result;
				},
			} as any, env);
			const emit = async (name: string, event: any = {}) => hooks.get(name)?.(event, context);
			const end = (stopReason = "stop") => emit("agent_end", {
				messages: [{ role: "assistant", stopReason, content: [{ type: "text", text: "Synthetic private response" }] }],
			});
			const complete = async (stopReason = "stop") => {
				await emit("agent_start"); await end(stopReason); await emit("agent_settled");
			};
			return { hooks, executions, warnings, context, emit, end, complete, setResult: (value: any) => { result = value; } };
		};
		const test = async (name: string, body: () => any) => {
			await body(); passed++; console.log(`PASS: ${name}`);
		};
		try {
			await test("only settled completion notifies, once, without response contents", async () => {
				const f = fixture();
				await f.emit("agent_start"); await f.end();
				assert.equal(f.executions.length, 0);
				assert.ok(!f.hooks.has("turn_end"), "individual tool/model turns must not notify");
				await f.emit("agent_settled"); await f.emit("agent_settled");
				assert.equal(f.executions.length, 1);
				const { command, args, options } = f.executions[0];
				assert.equal(command, "/synthetic/bin/notify-send");
				assert.equal(options.timeout, 5000);
				assert.ok(args.includes("--app-name=Pi") && args.includes("--"));
				assert.equal(args.at(-2), "Pi finished");
				assert.equal(args.at(-1), "fixture — Ready for input.");
				assert.doesNotMatch(args.join(" "), /Synthetic private response|\x1b|\x07/);
				await f.complete(); assert.equal(f.executions.length, 2);
			});
			await test("retries and queued follow-ups coalesce into the final completion", async () => {
				const f = fixture();
				await f.emit("agent_start"); await f.end("error");
				await f.emit("agent_start"); await f.end();
				await f.emit("agent_start"); await f.end();
				assert.equal(f.executions.length, 0);
				await f.emit("agent_settled");
				assert.equal(f.executions.length, 1);
				assert.equal(f.executions[0].args.at(-2), "Pi finished");
			});
			await test("a newly started continuation defers notification until idle", async () => {
				const f = fixture();
				await f.emit("agent_start"); await f.end();
				f.context.isIdle = () => false;
				await f.emit("agent_settled"); assert.equal(f.executions.length, 0);
				f.context.isIdle = () => true;
				await f.emit("agent_settled"); assert.equal(f.executions.length, 1);
			});
			await test("cancellations and tool-only/incomplete runs stay silent", async () => {
				const f = fixture();
				await f.complete("aborted"); await f.complete("toolUse");
				await f.emit("agent_start"); await f.emit("agent_end", { messages: [] }); await f.emit("agent_settled");
				assert.equal(f.executions.length, 0);
			});
			await test("terminal errors have a distinct notification without error details", async () => {
				const f = fixture(); await f.complete("error");
				assert.equal(f.executions[0].args.at(-2), "Pi stopped with an error");
				assert.equal(f.executions[0].args.at(-1), "fixture — Check the session for details.");
			});
			await test("RPC, JSON, and print modes do not notify", async () => {
				for (const mode of ["rpc", "json", "print"]) {
					const f = fixture({}, mode); await f.complete(); assert.equal(f.executions.length, 0);
				}
			});
			await test("subagents stay silent but the parent's own marker is allowed", async () => {
				for (const env of [{ PI_SUBAGENT_CHILD: "1" }, { PI_IS_SUBAGENT: "1" }, { PI_SUBAGENT_PARENT_SESSION: "another-session" }]) {
					const f = fixture(env); await f.complete(); assert.equal(f.executions.length, 0);
				}
				const root = fixture({ PI_SUBAGENT_PARENT_SESSION: "root-fixture" });
				await root.complete(); assert.equal(root.executions.length, 1);
			});
			await test("sessions without desktop D-Bus stay silent", async () => {
				const f = fixture({ DBUS_SESSION_BUS_ADDRESS: undefined });
				await f.complete(); assert.equal(f.executions.length, 0); assert.equal(f.warnings.length, 0);
			});
			await test("startup, session replacement, and shutdown never notify stale work", async () => {
				const f = fixture(); await f.emit("agent_settled");
				for (const reset of ["session_start", "session_shutdown"]) {
					await f.emit("agent_start"); await f.end(); await f.emit(reset); await f.emit("agent_settled");
				}
				assert.equal(f.executions.length, 0);
			});
			await test("project labels are bounded and escape markup and terminal controls", async () => {
				const f = fixture(); f.context.cwd = "/projects/--<name>&\x1b[31m\u202e";
				await f.complete();
				assert.equal(f.executions[0].args.at(-1), "--&lt;name&gt;&amp; — Ready for input.");
				f.context.cwd = "/projects/" + "🙂".repeat(150); await f.complete();
				assert.equal(Array.from(f.executions[1].args.at(-1).split(" — ")[0]).length, 120);
			});
			await test("delivery failures warn once without rejecting the completed turn", async () => {
				for (const result of [{ code: 1 }, { code: 0, killed: true }, new Error("synthetic failure")]) {
					const f = fixture(); f.setResult(result);
					await f.complete(); await f.emit("agent_settled");
					assert.equal(f.executions.length, 1); assert.equal(f.warnings.length, 1);
				}
			});
			await test("overlapping settled events cannot duplicate an in-flight delivery", async () => {
				const f = fixture(); let resolve!: (value: any) => void;
				f.setResult(new Promise(done => { resolve = done; }));
				await f.emit("agent_start"); await f.end();
				const delivery = f.emit("agent_settled");
				await f.emit("agent_settled"); assert.equal(f.executions.length, 1);
				resolve({ code: 0 }); await delivery;
			});
			writeFileSync(join(process.env.HOME!, "desktop-notify-smoke-passed"), `${passed}\n`);
		} catch (error) {
			console.error(error); process.exitCode = 1;
		} finally {
			ctx.shutdown();
		}
	});
}

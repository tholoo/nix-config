/** Per-prompt context in Pi's loader; synthetic editor, no provider or user editor. */
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import pairedEditor, { registerPairedEditor } from "../paired-editor.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const temp = mkdtempSync(join(tmpdir(), "paired-editor-"));
		const root = join(temp, "workspace");
		const socket = join(temp, "editor.sock");
		mkdirSync(join(root, "src"), { recursive: true });
		mkdirSync(join(temp, "workspace-other"));
		const user = (text: string, timestamp: number) => ({ role: "user", content: [{ type: "text", text }], timestamp });
		const fixture = (overrides: NodeJS.ProcessEnv = {}) => {
			const hooks = new Map<string, Function>();
			const env = { DEV_WORKSPACE_ROOT: root, DEV_NVIM_SOCKET: socket, ...overrides };
			const state = { line: 1, text: "function A() end", calls: 0, unavailable: false, status: undefined as string | undefined, session: "root-session" };
			const context = {
				mode: "tui", cwd: root, sessionManager: { getSessionId: () => state.session },
				ui: { setStatus(_key: string, value: string | undefined) { state.status = value; } },
			};
			registerPairedEditor({ on(name: string, callback: Function) { hooks.set(name, callback); } } as any, env, async address => {
				assert.equal(address, env.DEV_NVIM_SOCKET);
				state.calls++;
				if (state.unavailable) throw new Error("synthetic disconnect");
				return {
					version: 1, file: join(root, "fixture.lua"), cursor: { line: state.line, byte_col: 0 },
					modified: true, omitted: false,
					lines: [{ line: state.line, text: state.text, byte_col: 0, truncated: false }],
				};
			});
			const event = { messages: [user("what does this do?", 1)] as any[] };
			const run = () => hooks.get("context")!(event, context);
			return { hooks, context, event, env, state, run };
		};
		const attachment = (result: any) => result.messages.find((m: any) => m.customType === "paired-editor-context");
		let passed = 0;
		const test = async (name: string, body: () => any) => { await body(); passed++; console.log(`PASS: ${name}`); };
		try {
			await test("entrypoint registers context and session lifecycle hooks", () => {
				const hooks: string[] = [];
				pairedEditor({ on: (name: string) => hooks.push(name) } as any);
				assert.deepEqual(hooks, ["session_start", "session_shutdown", "context"]);
			});
			await test("snapshot is attached without rewriting user text or persisting messages", async () => {
				const f = fixture(), original = structuredClone(f.event);
				const result = await f.run(), message = attachment(result);
				assert.equal(message.display, false);
				assert.match(message.content, /function A/);
				assert.ok(message.content.includes(JSON.stringify(root)));
				assert.match(message.content, /Explicit targets take precedence/);
				assert.deepEqual(f.event, original);
				assert.deepEqual(result.messages[0], original.messages[0]);
				assert.match(f.state.status!, /fixture.lua:1.*\[\+\]/);
			});
			await test("function A then function B refreshes even without text changes", async () => {
				const f = fixture();
				const a = attachment(await f.run());
				f.state.line = 20;
				f.event.messages.push({ role: "assistant", content: "A explained", timestamp: 2 });
				f.event.messages.push(user("what about this?", 3));
				const result = await f.run(), b = attachment(result);
				assert.notEqual(a.content, b.content);
				assert.match(b.content, /"cursor":\{"line":20/);
				assert.equal(result.messages.filter((m: any) => m.customType).length, 1);
				assert.equal(f.state.calls, 2);
			});
			await test("tool continuations retain the prompt's snapshot and message ordering", async () => {
				const f = fixture();
				const before = attachment(await f.run()).content;
				f.state.line = 50; f.state.text = "new unsaved text";
				const assistant = { role: "assistant", content: [{ type: "toolCall", id: "x", name: "read", arguments: {} }], timestamp: 2 };
				const tool = { role: "toolResult", toolCallId: "x", toolName: "read", content: [], timestamp: 3 };
				f.event.messages.push(assistant, tool);
				const result = await f.run();
				assert.equal(attachment(result).content, before);
				assert.deepEqual(result.messages.slice(-2), [assistant, tool]);
				assert.equal(f.state.calls, 1);
			});
			await test("identical follow-up text still gets fresh context; queue delivery controls refresh", async () => {
				const f = fixture(); await f.run();
				f.state.line = 5;
				await f.run(); // A queued prompt is not yet in the model's messages.
				assert.equal(f.state.calls, 1);
				f.event.messages.push(user("what does this do?", 2));
				assert.match(attachment(await f.run()).content, /"cursor":\{"line":5/);
				assert.equal(f.state.calls, 2);
			});
			await test("unavailable editor clears old content and retries on the next prompt", async () => {
				const f = fixture(); await f.run();
				f.state.unavailable = true; f.event.messages.push(user("this?", 2));
				const failed = attachment(await f.run()).content;
				assert.match(failed, /unavailable/); assert.doesNotMatch(failed, /function A/);
				await f.run(); assert.equal(f.state.calls, 2);
				f.state.unavailable = false; f.state.text = "restarted editor";
				f.event.messages.push(user("try again", 3));
				assert.match(attachment(await f.run()).content, /restarted editor/);
			});
			await test("standalone, incomplete and relative bindings are no-ops", async () => {
				for (const env of [
					{ DEV_WORKSPACE_ROOT: undefined, DEV_NVIM_SOCKET: undefined },
					{ DEV_WORKSPACE_ROOT: undefined }, { DEV_NVIM_SOCKET: undefined },
					{ DEV_WORKSPACE_ROOT: "" }, { DEV_NVIM_SOCKET: "" },
					{ DEV_WORKSPACE_ROOT: "relative" }, { DEV_NVIM_SOCKET: "relative.sock" },
				]) { const f = fixture(env); assert.equal(await f.run(), undefined); assert.equal(f.state.calls, 0); }
			});
			await test("noninteractive modes and inherited child pairing stay inactive", async () => {
				for (const mode of ["rpc", "json", "print"]) {
					const f = fixture(); f.context.mode = mode;
					assert.equal(await f.run(), undefined); assert.equal(f.state.calls, 0);
				}
				for (const env of [{ PI_SUBAGENT_CHILD: "1" }, { PI_IS_SUBAGENT: "1" }, { PI_SUBAGENT_PARENT_SESSION: "parent-session" }]) {
					assert.equal(await fixture(env).run(), undefined);
				}
			});
			await test("subdirectories and canonical aliases retain the pairing", async () => {
				const f = fixture(); f.context.cwd = join(root, "src"); assert.ok(await f.run());
				const alias = join(temp, "alias"); symlinkSync(root, alias);
				f.context.cwd = alias; assert.ok(await f.run());
				f.env.DEV_WORKSPACE_ROOT = alias; f.context.cwd = root; assert.ok(await f.run());
			});
			await test("workspace boundaries clear cached context", async () => {
				const f = fixture(); await f.run();
				const escape = join(root, "escape"); symlinkSync(join(temp, "workspace-other"), escape);
				for (const cwd of [temp, join(temp, "workspace-other"), join(temp, "missing"), escape]) {
					f.context.cwd = cwd; assert.equal(await f.run(), undefined);
					assert.equal(f.state.status, undefined);
				}
				f.context.cwd = root; await f.run(); assert.equal(f.state.calls, 2);
				for (const name of ["nested-repo", "nested-worktree"]) {
					const nested = join(root, name); mkdirSync(join(nested, "src"), { recursive: true });
					if (name === "nested-repo") mkdirSync(join(nested, ".git"));
					else writeFileSync(join(nested, ".git"), "gitdir: /synthetic/git/worktrees/nested\n");
					f.context.cwd = join(nested, "src"); assert.equal(await f.run(), undefined);
				}
			});
			await test("session changes and shutdown discard snapshots", async () => {
				const f = fixture(); await f.run(); f.state.session = "new-session"; await f.run();
				assert.equal(f.state.calls, 2);
				f.hooks.get("session_shutdown")!({}, f.context); assert.equal(f.state.status, undefined);
				await f.run(); assert.equal(f.state.calls, 3);
			});
			await test("path data is escaped and no repeated context attachments accumulate", async () => {
				const odd = join(temp, 'workspace\n"odd"'); mkdirSync(odd);
				const f = fixture({ DEV_WORKSPACE_ROOT: odd, DEV_NVIM_SOCKET: socket + '\n"odd"' });
				f.context.cwd = odd;
				const result = await f.run();
				assert.ok(attachment(result).content.includes(JSON.stringify(odd)));
				assert.ok(!attachment(result).content.includes(odd));
				f.event.messages = result.messages;
				assert.equal((await f.run()).messages.filter((m: any) => m.customType).length, 1);
			});
			writeFileSync(join(process.env.PI_TEST_OUTPUT_DIR || process.env.HOME!, "paired-editor-smoke-passed"), `${passed}\n`);
		} catch (error) {
			console.error(error); process.exitCode = 1;
		} finally {
			rmSync(temp, { recursive: true, force: true }); ctx.shutdown();
		}
	});
}

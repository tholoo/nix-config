/** Pairing policy in Pi's loader, with private paths and no model/editor access. */
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
		const socket = join(temp, "not-running.sock");
		mkdirSync(join(root, "src"), { recursive: true });
		mkdirSync(join(temp, "workspace-other"));
		const fixture = (overrides: NodeJS.ProcessEnv = {}) => {
			const hooks = new Map<string, Function>();
			const env = { DEV_WORKSPACE_ROOT: root, DEV_NVIM_SOCKET: socket, ...overrides };
			const context = { mode: "tui", cwd: root, sessionManager: { getSessionId: () => "root-session" } };
			// Deliberately no exec, MCP, UI or persistence APIs: awareness is passive.
			registerPairedEditor({ on(name: string, callback: Function) { hooks.set(name, callback); } } as any, env);
			const event = { systemPrompt: "Existing chained prompt", prompt: "combine these functions" };
			const run = () => hooks.get("before_agent_start")!(event, context);
			return { hooks, context, event, env, run };
		};
		let passed = 0;
		const test = async (name: string, body: () => any) => {
			await body(); passed++; console.log(`PASS: ${name}`);
		};
		try {
			await test("entrypoint registers only a turn-local awareness hook", () => {
				const hooks: string[] = [];
				pairedEditor({ on: (name: string) => hooks.push(name) } as any);
				assert.deepEqual(hooks, ["before_agent_start"]);
			});
			await test("pairing is explicit but never claims a live editor", async () => {
				const f = fixture();
				const result = await f.run();
				assert.deepEqual(Object.keys(result), ["systemPrompt"]);
				assert.ok(result.systemPrompt.startsWith(f.event.systemPrompt + "\n\n"));
				assert.match(result.systemPrompt, /Connection and editor state are not yet verified/);
				assert.ok(result.systemPrompt.includes(JSON.stringify(root)));
				assert.ok(result.systemPrompt.includes(JSON.stringify(socket)));
				assert.match(result.systemPrompt, /inspect the paired editor through nvim MCP before choosing a target/);
				assert.match(result.systemPrompt, /explicit targets and clear conversation references take precedence/);
				assert.equal(f.event.systemPrompt, "Existing chained prompt");
				assert.deepEqual(await f.run(), result, "do not accumulate prompt additions across requests");
			});
			await test("standalone, incomplete and relative bindings are no-ops", async () => {
				for (const env of [
					{ DEV_WORKSPACE_ROOT: undefined, DEV_NVIM_SOCKET: undefined },
					{ DEV_WORKSPACE_ROOT: undefined }, { DEV_NVIM_SOCKET: undefined },
					{ DEV_WORKSPACE_ROOT: "" }, { DEV_NVIM_SOCKET: "" },
					{ DEV_WORKSPACE_ROOT: "relative" }, { DEV_NVIM_SOCKET: "relative.sock" },
				]) assert.equal(await fixture(env).run(), undefined);
			});
			await test("noninteractive modes and inherited child pairing stay inactive", async () => {
				for (const mode of ["rpc", "json", "print"]) {
					const f = fixture(); f.context.mode = mode;
					assert.equal(await f.run(), undefined);
				}
				for (const env of [{ PI_SUBAGENT_CHILD: "1" }, { PI_IS_SUBAGENT: "1" }, { PI_SUBAGENT_PARENT_SESSION: "parent-session" }]) {
					assert.equal(await fixture(env).run(), undefined);
				}
				assert.ok(await fixture({ PI_SUBAGENT_PARENT_SESSION: "root-session" }).run());
			});
			await test("subdirectories and canonical aliases retain the pairing", async () => {
				const f = fixture(); f.context.cwd = join(root, "src");
				assert.ok(await f.run());
				const alias = join(temp, "alias"); symlinkSync(root, alias);
				f.context.cwd = alias; assert.ok(await f.run());
				f.env.DEV_WORKSPACE_ROOT = alias; f.context.cwd = root;
				assert.ok(await f.run());
			});
			await test("workspace changes, missing paths and symlink escapes drop awareness", async () => {
				const f = fixture();
				const escape = join(root, "escape"); symlinkSync(join(temp, "workspace-other"), escape);
				for (const cwd of [temp, join(temp, "workspace-other"), join(temp, "missing"), escape]) {
					f.context.cwd = cwd; assert.equal(await f.run(), undefined);
				}
				f.context.cwd = root; assert.ok(await f.run(), "returning to the workspace re-enables awareness");
				f.env.DEV_WORKSPACE_ROOT = join(temp, "missing");
				assert.equal(await f.run(), undefined);
			});
			await test("nested repository and worktree boundaries are not the paired workspace", async () => {
				for (const name of ["nested-repo", "nested-worktree"]) {
					const nested = join(root, name); mkdirSync(join(nested, "src"), { recursive: true });
					if (name === "nested-repo") mkdirSync(join(nested, ".git"));
					else writeFileSync(join(nested, ".git"), "gitdir: /synthetic/git/worktrees/nested\n");
					const f = fixture(); f.context.cwd = join(nested, "src");
					assert.equal(await f.run(), undefined);
				}
			});
			await test("path data is JSON escaped rather than inserted as prompt lines", async () => {
				const odd = join(temp, 'workspace\n"odd"'); mkdirSync(odd);
				const f = fixture({ DEV_WORKSPACE_ROOT: odd, DEV_NVIM_SOCKET: socket + '\n"odd"' });
				f.context.cwd = odd;
				const result = await f.run();
				assert.ok(result.systemPrompt.includes(JSON.stringify(odd)));
				assert.ok(!result.systemPrompt.includes(odd));
			});
			writeFileSync(join(process.env.HOME!, "paired-editor-smoke-passed"), `${passed}\n`);
		} catch (error) {
			console.error(error); process.exitCode = 1;
		} finally {
			rmSync(temp, { recursive: true, force: true });
			ctx.shutdown();
		}
	});
}

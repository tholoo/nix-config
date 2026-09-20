/** Pinned gate + reviewer in Pi's SDK; synthetic provider, no commands executed. */
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdirSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import gate from "../node_modules/@gotgenes/pi-permission-system/precompiled/index.js";
import { getPermissionsService } from "../node_modules/@gotgenes/pi-permission-system/precompiled/service.js";
import review from "../node_modules/@mzwing/pi-permission-auto-review/dist/index.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		assert.equal(typeof ctx.modelRegistry.getProvider, "function");
		assert.equal(typeof ctx.modelRegistry.getApiKeyAndHeaders, "function");
		const agentDir = process.env.PI_CODING_AGENT_DIR!;
		const workspace = join(process.env.HOME!, "permission-workspace");
		mkdirSync(workspace, { recursive: true });
		// Model a managed skill symlink whose canonical source is also outside cwd.
		const skillSource = join(process.env.HOME!, "skill-source");
		const skillLink = join(process.env.HOME!, "managed-skill");
		mkdirSync(skillSource, { recursive: true });
		writeFileSync(join(skillSource, "SKILL.md"), "# Synthetic skill\n");
		symlinkSync(skillSource, skillLink);
		const outsideFile = join(process.env.HOME!, "outside.txt");
		const skillPrompt = `<available_skills><skill><name>fixture-skill</name><description>Synthetic skill</description><location>${skillLink}/SKILL.md</location></skill></available_skills>`;
		for (const [name, variable] of [
			["pi-permission-system", "PI_PERMISSION_TEST_CONFIG"],
			["pi-permission-auto-review", "PI_REVIEW_TEST_CONFIG"],
		]) {
			const directory = join(agentDir, "extensions", name);
			mkdirSync(directory, { recursive: true });
			writeFileSync(join(directory, "config.json"), readFileSync(process.env[variable]!));
		}
		let response = '{"outcome":"allow"}';
		let authenticated = true;
		let calls = 0;
		let prompts = 0;
		let lastPrompt = "";
		const model = { id: "synthetic-codex-template", provider: "openai-codex", api: "openai-codex-responses", reasoning: true };
		const provider = {
			getModels: () => [model],
			streamSimple(selected: any, context: any, options: any) {
				assert.equal(selected.id, "codex-auto-review");
				assert.equal(options.apiKey, "synthetic-test-credential");
				assert.equal(options.maxRetries, 0);
				calls++;
				lastPrompt = context.messages[0].content;
				assert.match(lastPrompt, /Inspect the synthetic fixture/);
				return { result: async () => ({ content: [{ type: "text", text: response }], stopReason: "stop" }) };
			},
		};
		const registry = {
			getProvider(name: string) { assert.equal(name, "openai-codex"); return provider; },
			find: () => undefined,
			getAll: () => [model],
			getApiKeyAndHeaders: async () => authenticated ? { ok: true, apiKey: "synthetic-test-credential" } : { ok: false },
		};
		const sessionManager = (base: any, id: string, branch: any[]) => new Proxy(base, {
			get(target, key) {
				if (key === "getSessionId") return () => id;
				if (key === "getBranch") return () => branch;
				const value = Reflect.get(target, key);
				return typeof value === "function" ? value.bind(target) : value;
			},
		});
		const context: any = {
			...ctx, cwd: workspace, hasUI: true, mode: "rpc", modelRegistry: registry,
			isProjectTrusted: () => false,
			sessionManager: sessionManager(ctx.sessionManager, "permissions-smoke-root", [
				{ type: "message", id: "user-fixture", message: { role: "user", content: "Inspect the synthetic fixture", timestamp: 1 } },
			]),
			ui: { ...ctx.ui, setStatus() {}, notify() {}, select: async () => { prompts++; return undefined; } },
		};
		const commands = new Set<string>();
		const makeExtension = (factory: Function, extensionContext = context, events = pi.events) => {
			const hooks = new Map<string, Function[]>();
			let active = ["bash", "read", "write", "edit", "process"];
			factory({
				...pi, events,
				on(name: string, fn: Function) { hooks.set(name, [...(hooks.get(name) ?? []), fn]); },
				registerCommand(name: string) { commands.add(name); },
				getAllTools: () => ["bash", "read", "write", "edit", "process"].map(name => ({ name, description: name, parameters: { type: "object" } })),
				getActiveTools: () => active,
				setActiveTools: (names: string[]) => { active = names; },
			});
			return async (name: string, event: any = {}) => {
				let result: any;
				for (const hook of hooks.get(name) ?? []) result = await hook(event, extensionContext);
				return result;
			};
		};
		const gateEvent = makeExtension(gate);
		const reviewEvent = makeExtension(review);
		let passed = 0;
		const test = async (name: string, body: () => any) => {
			await body(); passed++; console.log(`PASS: ${name}`);
		};
		const tool = (toolName: string, input: any) => gateEvent("tool_call", { toolName, input, toolCallId: `fixture-${passed}` });
		try {
			await gateEvent("session_start", { reason: "startup" });
			await reviewEvent("session_start", { reason: "startup" });
			await gateEvent("before_agent_start", { systemPrompt: skillPrompt, prompt: "Inspect the synthetic fixture" });
			await test("both extensions load and share the keyed service, even gate-first", () => {
				const service = getPermissionsService("permissions-smoke-root")!;
				assert.ok(service);
				assert.equal(service.getToolPermission("bash"), "ask");
				assert.equal(service.checkPermission("bash", "git push --force origin main").state, "ask");
				assert.throws(() => service.registerAuthorizer("auto-review", async () => ({ kind: "defer" })), /already|registered/i);
				assert.ok(commands.has("permission-system") && commands.has("permission-auto-review"));
			});
			await test("workspace reads need no reviewer or human prompt", async () => {
				assert.notEqual((await tool("read", { path: "fixture.txt" }))?.block, true);
				assert.equal(calls, 0); assert.equal(prompts, 0);
			});
			await test("auto-review approves shell asks using the Codex provider", async () => {
				assert.notEqual((await tool("bash", { command: "git status" }))?.block, true);
				assert.equal(calls, 1); assert.equal(prompts, 0);
			});
			await test("a review denial blocks a force-push request without executing it", async () => {
				response = '{"outcome":"deny","rationale":"Synthetic denial"}';
				assert.equal((await tool("bash", { command: "git push --force origin main" })).block, true);
				assert.match(lastPrompt, /git push --force origin main/);
				assert.equal(prompts, 0);
			});
			await test("background process launches are reviewed as shell commands", async () => {
				const before = calls;
				assert.equal((await tool("process", { action: "start", command: "git push --force origin main", cwd: workspace })).block, true);
				assert.ok(calls > before);
				assert.match(lastPrompt, /git push --force origin main/);
			});
			await reviewEvent("turn_start");
			await test("process stdin writes cannot bypass the generic tool gate", async () => {
				const before = calls;
				assert.equal((await tool("process", { action: "write", id: "fixture", input: "dangerous input" })).block, true);
				assert.ok(calls > before);
			});
			await reviewEvent("turn_start");
			await test("authentication failures fall back to the human prompt", async () => {
				authenticated = false;
				const before = calls;
				assert.equal((await tool("bash", { command: "git status" })).block, true);
				assert.equal(calls, before); assert.equal(prompts, 1);
				authenticated = true;
			});
			await test("invalid model responses fall back to the human prompt", async () => {
				response = "not-json";
				assert.equal((await tool("bash", { command: "git status" })).block, true);
				assert.equal(prompts, 2);
			});
			await test("outside-workspace writes proceed after model approval", async () => {
				response = '{"outcome":"allow"}';
				const before = calls;
				const beforePrompts = prompts;
				const result = await tool("write", { path: outsideFile, content: "synthetic" });
				assert.notEqual(result?.block, true, result?.reason);
				assert.ok(calls > before, "outside access must be reviewed, not blanket-allowed");
				assert.equal(prompts, beforePrompts);
			});
			await test("symlinked skills and their canonical source pass through auto-review", async () => {
				const before = calls;
				const beforePrompts = prompts;
				for (const directory of [skillLink, skillSource]) {
					const result = await tool("read", { path: join(directory, "SKILL.md") });
					assert.notEqual(result?.block, true, result?.reason);
				}
				assert.ok(calls >= before + 2);
				assert.equal(prompts, beforePrompts);
			});
			await test("shell and background outside-directory accesses are reviewable", async () => {
				const beforePrompts = prompts;
				for (const name of ["bash", "process"]) {
					const before = calls;
					const result = await tool(name, { action: "start", command: `cat ${JSON.stringify(outsideFile)}`, cwd: workspace });
					assert.notEqual(result?.block, true, result?.reason);
					assert.ok(calls > before);
				}
				assert.equal(prompts, beforePrompts);
			});
			await test("outside-workspace model denials still block without prompting", async () => {
				response = '{"outcome":"deny","rationale":"Synthetic outside-access denial"}';
				const before = calls;
				const beforePrompts = prompts;
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(calls, before + 1);
				assert.equal(prompts, beforePrompts);
				response = '{"outcome":"allow"}';
			});
			await test("outside-workspace reviewer failures still need human approval", async () => {
				authenticated = false;
				const beforePrompts = prompts;
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(prompts, beforePrompts + 1);
				authenticated = true;
			});
			const withRule = async (surface: string, action: string, body: () => Promise<void>) => {
				const file = join(agentDir, "extensions/pi-permission-system/config.json");
				const original = readFileSync(file, "utf8");
				const config = JSON.parse(original);
				config.permission[surface] = { "*": config.permission[surface], [outsideFile]: action };
				try {
					writeFileSync(file, JSON.stringify(config));
					await gateEvent("resources_discover", { reason: "reload" });
					await body();
				} finally {
					writeFileSync(file, original);
					await gateEvent("resources_discover", { reason: "reload" });
				}
			};
			await test("explicit path asks remain human-only despite model approval", () => withRule("path", "ask", async () => {
				const beforePrompts = prompts;
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(prompts, beforePrompts + 1);
			}));
			await test("explicit path denials cannot be overridden by auto-review", () => withRule("path", "deny", async () => {
				const before = calls;
				const beforePrompts = prompts;
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(calls, before);
				assert.equal(prompts, beforePrompts);
			}));
			await test("explicit outside-directory denials bypass the reviewer and block", () => withRule("external_directory", "deny", async () => {
				const before = calls;
				const beforePrompts = prompts;
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(calls, before);
				assert.equal(prompts, beforePrompts);
			}));
			await test("headless child asks forward to the parent's reviewer", async () => {
				const prior = process.env.PI_SUBAGENT_PARENT_SESSION;
				process.env.PI_SUBAGENT_PARENT_SESSION = "permissions-smoke-root";
				const emitter = new EventEmitter();
				const events = {
					on(name: string, handler: any) { emitter.on(name, handler); return () => { emitter.off(name, handler); }; },
					emit(name: string, data: any) { emitter.emit(name, data); },
				};
				const childContext = {
					...context, hasUI: false,
					sessionManager: sessionManager(ctx.sessionManager, "permissions-smoke-child", []),
				};
				const childEvent = makeExtension(gate, childContext, events);
				try {
					await childEvent("session_start", { reason: "startup" });
					const before = calls;
					const beforePrompts = prompts;
					const result = await childEvent("tool_call", { toolName: "bash", input: { command: "git status" }, toolCallId: "child-fixture" });
					assert.notEqual(result?.block, true, result?.reason);
					const external = await childEvent("tool_call", { toolName: "read", input: { path: outsideFile }, toolCallId: "child-external-fixture" });
					assert.notEqual(external?.block, true, external?.reason);
					assert.equal(calls, before + 2);
					assert.equal(prompts, beforePrompts);
				} finally {
					await childEvent("session_shutdown");
					if (prior === undefined) delete process.env.PI_SUBAGENT_PARENT_SESSION;
					else process.env.PI_SUBAGENT_PARENT_SESSION = prior;
				}
			});
			await reviewEvent("session_shutdown");
			await test("a missing reviewer prompts instead of silently allowing", async () => {
				const beforePrompts = prompts;
				assert.equal((await tool("bash", { command: "git status" })).block, true);
				assert.equal((await tool("read", { path: outsideFile })).block, true);
				assert.equal(prompts, beforePrompts + 2);
			});
			writeFileSync(join(process.env.HOME!, "permissions-smoke-passed"), `${passed}\n`);
		} catch (error) {
			console.error(error); process.exitCode = 1;
		} finally {
			await reviewEvent("session_shutdown");
			await gateEvent("session_shutdown");
			ctx.shutdown();
		}
	});
}

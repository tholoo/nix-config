/** Real Pi TUI utilities + the pinned process event bridge; no model or user session. */
import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import status from "../processes-status.js";
import { CHANNELS } from "../node_modules/@aliou/pi-processes/extensions/shared/protocol/channels.js";
import { registerEventBridge } from "../node_modules/@aliou/pi-processes/extensions/processes/hooks/event-bridge.js";
import { ProcessManager } from "../node_modules/@aliou/pi-processes/src/manager/index.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const hooks = new Map<string, Function>();
		status({ events: pi.events, on(name: string, callback: Function) { hooks.set(name, callback); } } as any);
		let component: any;
		let widgets = 0;
		let queries = 0;
		let mutationCommands = 0;
		let records: any[] = [];
		const stopMutations = [CHANNELS.COMMAND_CLEAR, CHANNELS.COMMAND_KILL, CHANNELS.COMMAND_START]
			.map((channel) => pi.events.on(channel, () => { mutationCommands++; }));
		let stopList = pi.events.on(CHANNELS.REQUEST_LIST, (payload: any) => { queries++; payload.reply(records); });
		const ui = {
			setWidget(key: string, value: any, options: any) {
				assert.equal(key, "running-processes");
				assert.equal(options.placement, "belowEditor");
				widgets++;
				component = typeof value === "function" ? value({}, ctx.ui.theme) : value;
			},
		};
		const start = (mode = "tui") => hooks.get("session_start")!({}, { mode, ui });
		const shutdown = () => hooks.get("session_shutdown")!();
		const changed = () => pi.events.emit(CHANNELS.CHANGED, { reason: "started" });
		const text = (width = 200) => stripVTControlCharacters(component?.render(width).join("\n") ?? "");
		const row = (id: string, name: string, state: string, time = 1) => ({ id, name, status: state, startTime: time });
		let passed = 0;
		const test = async (name: string, body: () => void | Promise<void>) => {
			await body();
			passed++;
			console.log(`PASS: ${name}`);
		};
		const waitFor = async (condition: () => boolean) => {
			const deadline = Date.now() + 5000;
			while (!condition()) {
				assert.ok(Date.now() < deadline, "process fixture timed out");
				await new Promise((resolve) => setTimeout(resolve, 10));
			}
		};
		let manager: any;
		let stopBridge: (() => void) | undefined;
		try {
			await test("completed, failed and killed records remain stored but invisible", () => {
				records = [
					{ ...row("done", "successful-job", "exited"), success: true },
					{ ...row("bad", "failed-job", "exited"), success: false },
					row("killed", "killed-job", "killed"),
				];
				const original = structuredClone(records);
				start();
				assert.equal(component, undefined);
				assert.deepEqual(records, original);
			});
			await test("live jobs appear in stable order with an active count", () => {
				records.push(row("watch", "watcher", "running", 20), row("build", "build", "running", 10));
				changed();
				assert.match(text(), /2 active.*build.*watcher/);
				assert.doesNotMatch(text(), /successful-job|failed-job|killed-job/);
				assert.equal(records.at(-1).id, "build", "display sorting must not reorder manager data");
			});
			await test("unchanged events and output bursts do not redraw", () => {
				const before = widgets;
				changed();
				assert.equal(widgets, before);
				const beforeQueries = queries;
				pi.events.emit(CHANNELS.OUTPUT_CHANGED, { id: "build" });
				assert.equal(queries, beforeQueries);
			});
			await test("still-live stopping and timed-out-stop jobs remain visible", () => {
				records = [row("a", "stopping-job", "terminating"), row("b", "stuck-job", "terminate_timeout")];
				changed();
				assert.match(text(), /2 active.*stopping-job \(stopping\).*stuck-job \(stop timed out\)/);
			});
			await test("ANSI, control characters, Unicode and narrow widths are safe", () => {
				records = [row("unicode", "\x1b[31m编译 🧪\x1b[0m\nname\r\t\x1b", "running")];
				changed();
				assert.doesNotMatch(text(), /[\x00-\x1f\x7f-\x9f]/u);
				assert.match(text(), /编译 🧪/);
				for (const width of [0, 1, 2, 3, 5, 10, 30, 100]) {
					for (const line of component.render(width)) assert.ok(visibleWidth(line) <= width, `${width}: ${line}`);
				}
				component.invalidate();
				assert.match(text(100), /编译 🧪/);
			});
			await test("last exit removes the widget without clearing history", () => {
				records[0].status = "exited";
				changed();
				assert.equal(component, undefined);
				assert.equal(records.length, 1);
				assert.equal(mutationCommands, 0);
			});
			await test("reload/switch/shutdown dispose listeners and rebuild snapshots", () => {
				records = [row("new", "resumed-job", "running")];
				start();
				assert.match(text(), /resumed-job/);
				start(); // Defensive repeated start must not duplicate subscriptions.
				const before = queries;
				changed();
				assert.equal(queries, before + 1);
				shutdown(); shutdown();
				const after = queries;
				changed();
				assert.equal(queries, after);
				assert.equal(component, undefined);
			});
			await test("RPC, JSON and print modes do not install a TUI widget", () => {
				const before = [widgets, queries];
				for (const mode of ["rpc", "json", "print"]) { start(mode); changed(); shutdown(); }
				assert.deepEqual([widgets, queries], before);
			});
			await test("absent process extension is harmless", () => {
				stopList();
				start();
				assert.equal(component, undefined);
				shutdown();
			});

			// Real process manager and upstream lifecycle bridge. Both successful and
			// failing fixtures retain their records and logs after leaving the widget.
			manager = new ProcessManager({ getConfiguredShellPath: () => process.env.SHELL });
			stopList = pi.events.on(CHANNELS.REQUEST_LIST, (payload: any) => payload.reply(manager.list()));
			stopBridge = registerEventBridge(pi.events, manager);
			start();
			await test("real successful process disappears while its logs remain readable", async () => {
				const info = manager.start("live-fixture", "printf 'ready\\n'; read -r answer; printf 'retained success\\n'", process.env.HOME);
				assert.match(text(), /live-fixture/);
				await waitFor(() => manager.getOutput(info.id)?.stdout.join("\n").includes("ready"));
				assert.equal(manager.writeToStdin(info.id, "finish\n").ok, true);
				await waitFor(() => manager.get(info.id)?.status === "exited");
				assert.equal(component, undefined);
				assert.equal(manager.get(info.id).success, true);
				assert.ok(existsSync(info.stdoutFile));
				assert.match(readFileSync(info.stdoutFile, "utf8"), /retained success/);
			});
			await test("real failed process disappears without deleting its diagnostics", async () => {
				const info = manager.start("failure-fixture", "printf 'retained failure\\n' >&2; exit 7", process.env.HOME);
				await waitFor(() => manager.get(info.id)?.status === "exited");
				assert.equal(component, undefined);
				assert.equal(manager.get(info.id).exitCode, 7);
				assert.match(readFileSync(info.stderrFile, "utf8"), /retained failure/);
				assert.equal(manager.list().length, 2);
				assert.equal(mutationCommands, 0);
			});
			writeFileSync(join(process.env.HOME!, "processes-status-smoke-passed"), `${passed} passed\n`);
			console.log(`Running-process widget: ${passed} scenarios passed`);
		} finally {
			shutdown();
			stopList(); stopBridge?.();
			for (const stop of stopMutations) stop();
			manager?.killAll(); manager?.cleanup();
		}
		process.exit(0);
	});
}

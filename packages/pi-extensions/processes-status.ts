/** Read-only companion to @aliou/pi-processes; never clears records or logs. */
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

// The pinned package uses these channels for its own dock as well. Keep the
// small protocol boundary explicit rather than importing private package code.
const REQUEST_LIST = "processes:request:list";
const CHANGED = "processes:changed";
const WIDGET = "running-processes";
const PLACEMENT = { placement: "belowEditor" } as const;

interface ProcessSummary {
	id: string;
	name: string;
	status: string;
	startTime: number;
}

// A timed-out stop is not a dead process: keep it visible until it really exits.
const LIVE = new Set(["running", "terminating", "terminate_timeout"]);
const label = (process: ProcessSummary) => {
	const name = stripVTControlCharacters(process.name)
		.replace(/[\x00-\x1f\x7f-\x9f\u2028\u2029]/gu, " ")
		.trim();
	const suffix = process.status === "terminating" ? " (stopping)"
		: process.status === "terminate_timeout" ? " (stop timed out)" : "";
	return (name || process.id) + suffix;
};

export function renderProcesses(processes: readonly ProcessSummary[], theme: Theme, width: number): string[] {
	if (width <= 0 || processes.length === 0) return [];
	const names = processes.map((process) =>
		theme.fg(process.status === "running" ? "muted" : "warning", label(process)));
	return [truncateToWidth(
		theme.fg("accent", `● ${processes.length} active`) + theme.fg("dim", " · ") + names.join(theme.fg("dim", " · ")),
		width,
	)];
}

export default function processesStatus(pi: ExtensionAPI) {
	let dispose: (() => void) | undefined;

	pi.on("session_start", (_event, ctx) => {
		dispose?.();
		dispose = undefined;
		// Component factories are TUI-only, not RPC/JSON/print UI surfaces.
		if (ctx.mode !== "tui") return;
		let signature: string | undefined;
		const refresh = () => {
			let rows: ProcessSummary[] = [];
			pi.events.emit(REQUEST_LIST, {
				reply(processes: ProcessSummary[]) {
					rows = processes.filter((process) => LIVE.has(process.status))
						.map(({ id, name, status, startTime }) => ({ id, name, status, startTime }))
						.sort((a, b) => a.startTime - b.startTime || a.id.localeCompare(b.id));
				},
			});
			const next = JSON.stringify(rows);
			if (signature === next) return;
			signature = next;
			if (rows.length === 0) {
				ctx.ui.setWidget(WIDGET, undefined, PLACEMENT);
			} else {
				ctx.ui.setWidget(WIDGET, (_tui, theme) => ({
					render: (width) => renderProcesses(rows, theme, width),
					invalidate() {}, // No cached theme colors or width-dependent output.
				}), PLACEMENT);
			}
		};
		const unsubscribe = pi.events.on(CHANGED, refresh);
		dispose = () => {
			unsubscribe();
			ctx.ui.setWidget(WIDGET, undefined, PLACEMENT);
		};
		refresh();
	});
	pi.on("session_shutdown", () => {
		dispose?.();
		dispose = undefined;
	});
}

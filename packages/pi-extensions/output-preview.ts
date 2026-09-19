/** Display-only policy for the pinned Claude UI patch. No result mutation or I/O. */
export interface OutputPreviewSettings {
	completedToolPreview?: boolean;
	outputPreviewFullLines?: number;
	outputPreviewHeadLines?: number;
	outputPreviewTailLines?: number;
	failurePreviewTailLines?: number;
	bashAlwaysShowCommand?: boolean;
}

export type PreviewRow = { text: string } | { hidden: number };

// Bound user-provided settings so a typo cannot dump an entire log by default.
function lineLimit(value: unknown, fallback: number): number {
	return typeof value === "number" && Number.isFinite(value) && value >= 0
		? Math.min(200, Math.floor(value))
		: fallback;
}

export function outputLines(text: string): string[] {
	if (!text) return [];
	const lines = text.replace(/\r\n?/g, "\n").split("\n");
	// A final newline terminates a line; internal blank lines still count.
	if (lines.at(-1) === "") lines.pop();
	return lines;
}

export function selectOutputPreview(
	lines: readonly string[],
	settings: OutputPreviewSettings,
	failed = false,
): PreviewRow[] {
	const full = lineLimit(settings.outputPreviewFullLines, 8);
	const head = lineLimit(settings.outputPreviewHeadLines, 3);
	const normalTail = lineLimit(settings.outputPreviewTailLines, 3);
	const tail = failed ? Math.max(normalTail, lineLimit(settings.failurePreviewTailLines, 12)) : normalTail;
	if (lines.length <= Math.max(full, head + tail)) return lines.map((text) => ({ text }));
	return [
		...lines.slice(0, head).map((text) => ({ text })),
		{ hidden: lines.length - head - tail },
		...(tail > 0 ? lines.slice(-tail).map((text) => ({ text })) : []),
	];
}

/** Only interpret Pi's final Bash failure footer, never arbitrary stdout. */
export function bashFailureLabel(text: string, failed: boolean): string {
	if (!failed) return "Done";
	const exit = text.match(/(?:^|\n)Command exited with code (\d+)\s*$/);
	return exit ? `Exit ${exit[1]}` : "Failed";
}

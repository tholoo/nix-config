import assert from "node:assert/strict";
import { test } from "node:test";
import { bashFailureLabel, outputLines, selectOutputPreview } from "../output-preview.ts";

const lines = (n) => Array.from({ length: n }, (_, i) => `line ${i + 1}`);
const texts = (rows) => rows.filter((row) => "text" in row).map((row) => row.text);

for (const count of [0, 1, 6, 7, 8]) {
	test(`shows all ${count} short output lines without a gap`, () => {
		assert.deepEqual(selectOutputPreview(lines(count), {}), lines(count).map((text) => ({ text })));
	});
}
test("long output retains first/last three with exact omitted count", () => {
	assert.deepEqual(selectOutputPreview(lines(9), {}), [
		{ text: "line 1" }, { text: "line 2" }, { text: "line 3" }, { hidden: 3 },
		{ text: "line 7" }, { text: "line 8" }, { text: "line 9" },
	]);
});
test("failure retains first three and last twelve", () => {
	const preview = selectOutputPreview(lines(30), {}, true);
	assert.deepEqual(texts(preview), [...lines(30).slice(0, 3), ...lines(30).slice(-12)]);
	assert.deepEqual(preview[3], { hidden: 15 });
});
test("failure windows never overlap or hide a lone line", () => {
	assert.deepEqual(texts(selectOutputPreview(lines(15), {}, true)), lines(15));
	assert.equal(selectOutputPreview(lines(15), {}, true).length, 15);
});
test("configured limits and zero-length windows", () => {
	assert.deepEqual(selectOutputPreview(lines(9), { outputPreviewFullLines: 0, outputPreviewHeadLines: 0, outputPreviewTailLines: 0 }), [{ hidden: 9 }]);
	assert.deepEqual(selectOutputPreview(lines(9), { outputPreviewFullLines: 0, outputPreviewHeadLines: 1, outputPreviewTailLines: 0 }), [{ text: "line 1" }, { hidden: 8 }]);
	assert.deepEqual(selectOutputPreview(lines(9), { outputPreviewFullLines: 0, outputPreviewHeadLines: 0, outputPreviewTailLines: 1 }), [{ hidden: 8 }, { text: "line 9" }]);
});
test("invalid values fall back, fractions floor, excessive limits cap", () => {
	for (const invalid of [-1, NaN, Infinity, "10", null]) {
		assert.deepEqual(selectOutputPreview(lines(20), { outputPreviewHeadLines: invalid }), selectOutputPreview(lines(20), {}));
	}
	assert.equal(texts(selectOutputPreview(lines(20), { outputPreviewHeadLines: 1.9 })).length, 4);
	assert.equal(texts(selectOutputPreview(lines(1000), { outputPreviewHeadLines: 1000000 })).length, 203);
});
test("failure budget never reduces the configured normal tail", () => {
	assert.equal(texts(selectOutputPreview(lines(100), { outputPreviewTailLines: 20, failurePreviewTailLines: 4 }, true)).length, 23);
});
test("line splitting preserves indentation, blank lines and ANSI", () => {
	assert.deepEqual(outputLines("  start\r\n\r\n\u001b[31mend\u001b[0m\n"), ["  start", "", "\u001b[31mend\u001b[0m"]);
	assert.deepEqual(outputLines(""), []);
	assert.deepEqual(outputLines("\n"), [""]);
	assert.deepEqual(outputLines("a\n\n"), ["a", ""]);
});
test("selection does not mutate source lines", () => {
	const source = Object.freeze(lines(100));
	selectOutputPreview(source, {}, true);
	assert.deepEqual(source, lines(100));
});
test("exit status only comes from a failed result's final Pi footer", () => {
	assert.equal(bashFailureLabel("error\n\nCommand exited with code 7\n", true), "Exit 7");
	assert.equal(bashFailureLabel("Command exited with code 7", false), "Done");
	assert.equal(bashFailureLabel("example: exit code: 2", false), "Done");
	assert.equal(bashFailureLabel("Command exited with code 7\nmore output", true), "Failed");
	assert.equal(bashFailureLabel("Command timed out after 10 seconds", true), "Failed");
});

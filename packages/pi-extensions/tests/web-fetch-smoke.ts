/** Exercise the packaged extractor through Pi's loader, without external requests. */
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { extractContent } from "../node_modules/pi-web-access/extract.js";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const paragraph = "Synthetic extraction fixture: this article explains how readable HTML becomes Markdown while preserving useful source text and links. ".repeat(10);
		const html = `<!doctype html><html><head><title>Extraction fixture</title></head><body><article><h1>Extraction fixture</h1><p>${paragraph}</p><h2>Code sample</h2><pre><code>const answer = 42;</code></pre><p><a href="https://example.org/reference">Reference link</a></p></article></body></html>`;
		const shortHtml = "<!doctype html><html><head><title>Short fixture</title></head><body><p>Short fixture content.</p></body></html>";
		const server = createServer((req, res) => {
			if (req.url === "/redirect") {
				res.writeHead(302, { Location: "/article" });
				res.end();
				return;
			}
			res.writeHead(req.url === "/missing" ? 404 : 200, {
				"Content-Type": req.url === "/plain" ? "text/plain" : "text/html; charset=utf-8",
			});
			res.end(req.url === "/short" ? shortHtml : req.url === "/plain" ? "Plain fixture text." : html);
		});
		try {
			writeFileSync(join(process.env.PI_CODING_AGENT_DIR!, "web-search.json"), JSON.stringify({
				allowBrowserCookies: false,
				fetchRouting: { providers: ["http"], allowRemoteHostedProviders: false },
				ssrf: { allowRanges: ["127.0.0.1/32"] },
			}));
			await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
			const address = server.address();
			assert.ok(address && typeof address === "object");
			const url = `http://127.0.0.1:${address.port}/article`;
			const raw = await extractContent(url, undefined, { mode: "raw", proxy: "" });
			assert.equal(raw.error, null);
			assert.equal(raw.content, html);
			const readable = await extractContent(url, undefined, { mode: "readable", proxy: "" });
			assert.equal(readable.error, null);
			assert.equal(readable.title, "Extraction fixture");
			assert.ok(readable.content.includes(paragraph.trim()));
			assert.match(readable.content, /## Code sample/);
			assert.match(readable.content, /```[\s\S]*const answer = 42;[\s\S]*```/);
			assert.match(readable.content, /\[Reference link\]\(https:\/\/example.org\/reference\)/);
			const redirected = await extractContent(url.replace("/article", "/redirect"), undefined, { proxy: "" });
			assert.equal(redirected.error, null);
			assert.equal(redirected.content, readable.content);
			const plain = await extractContent(url.replace("/article", "/plain"), undefined, { proxy: "" });
			assert.equal(plain.error, null);
			assert.equal(plain.content, "Plain fixture text.");
			// Readability's result is under 500 characters, forcing the real Defuddle
			// fallback to load. A short page must retain the upstream quality warning,
			// not a loader error or a false claim of complete extraction.
			const short = await extractContent(url.replace("/article", "/short"), undefined, { proxy: "" });
			assert.ok(short.error?.startsWith("Extracted content appears incomplete"), short.error ?? "missing quality warning");
			assert.match(short.content, /Short fixture content\./);
			assert.doesNotMatch(short.error!, /Cannot find|ResolveMessage|Dynamic require|Defuddle failed/);
			const missing = await extractContent(url.replace("/article", "/missing"), undefined, { proxy: "" });
			assert.equal(missing.status, 404);
			assert.ok(missing.error);
			const blocked = await extractContent("http://10.0.0.1/fixture", undefined, { proxy: "" });
			assert.match(blocked.error ?? "", /Blocked internal/);
			writeFileSync(join(process.env.HOME!, "web-fetch-smoke-passed"), "passed\n");
			console.log("PASS: raw/readable HTML, lazy Defuddle fallback, redirects, plain text, HTTP errors and SSRF protection through Pi's loader");
		} catch (error) {
			console.error(error);
			process.exitCode = 1;
		} finally {
			server.closeAllConnections();
			await new Promise<void>(resolve => server.close(() => resolve()));
			ctx.shutdown();
		}
	});
}

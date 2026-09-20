/** Advertise the launcher's editor pairing, without probing or reading the editor. */
import { lstat, realpath } from "node:fs/promises";
import { dirname, isAbsolute, join, relative, sep } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

async function matchingWorkspace(cwd: string, root: string): Promise<string | undefined> {
	try {
		const canonicalRoot = await realpath(root);
		let directory = await realpath(cwd);
		const suffix = relative(canonicalRoot, directory);
		if (suffix === ".." || suffix.startsWith(`..${sep}`) || isAbsolute(suffix)) return;
		// A nested repository/worktree is not the launcher's workspace. Avoid Git
		// subprocesses/config and accept ordinary subdirectories and symlink aliases.
		while (directory !== canonicalRoot) {
			try {
				await lstat(join(directory, ".git"));
				return;
			} catch (error) {
				if ((error as NodeJS.ErrnoException).code !== "ENOENT") return;
			}
			directory = dirname(directory);
		}
		return canonicalRoot;
	} catch {
		// Missing/inaccessible workspace: omit awareness rather than guess.
		return;
	}
}

export function registerPairedEditor(pi: ExtensionAPI, env: NodeJS.ProcessEnv = process.env) {
	pi.on("before_agent_start", async (event, ctx: ExtensionContext) => {
		const root = env.DEV_WORKSPACE_ROOT;
		const socket = env.DEV_NVIM_SOCKET;
		const parent = env.PI_SUBAGENT_PARENT_SESSION;
		if (ctx.mode !== "tui" || env.PI_SUBAGENT_CHILD === "1" || env.PI_IS_SUBAGENT === "1"
			|| (parent && parent !== ctx.sessionManager.getSessionId())
			|| !root || !socket || !isAbsolute(root) || !isAbsolute(socket)) return;
		const workspace = await matchingWorkspace(ctx.cwd, root);
		if (!workspace) return;

		// Turn-local prompt addition, not a persisted message or cached editor
		// snapshot. Re-evaluate after session/cwd changes. An absent socket may be
		// an editor starting/restarting; only an MCP read can verify availability.
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Paired editor (current request)\n`
				+ `The launcher configured a paired Neovim editor for this workspace. Connection and editor state are not yet verified.\n`
				+ `Workspace path (JSON): ${JSON.stringify(workspace)}\n`
				+ `Neovim socket (JSON): ${JSON.stringify(socket)}\n`
				+ `For ambiguous references such as "this function", "these functions", or "the selected code", inspect the paired editor through nvim MCP before choosing a target. Follow the editor-use instructions; explicit targets and clear conversation references take precedence.\n`,
		};
	});
}

export default function (pi: ExtensionAPI) {
	registerPairedEditor(pi);
}

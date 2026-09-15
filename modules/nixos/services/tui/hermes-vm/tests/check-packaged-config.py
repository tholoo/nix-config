"""Check a built Hermes package against its generated, non-secret base config.

Usage: python3 check-packaged-config.py PACKAGE CONFIG_JSON [LOCALES]
All HTTP responses are mocked; account files and real services are not used.
"""

import ast
import asyncio
import inspect
import json
import os
from pathlib import Path
import site
import sys
import tempfile
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch


def main():
    package, config_path = map(Path, sys.argv[1:3])
    cfg = json.loads(config_path.read_text())
    # The Nix Python entry point records the package's complete import closure.
    wrapper = ast.parse((package / "bin/.hermes-wrapped").read_text())
    for node in ast.walk(wrapper):
        if isinstance(node, ast.List) and node.elts and all(
            isinstance(item, ast.Constant) and isinstance(item.value, str)
            for item in node.elts
        ):
            for item in node.elts:
                site.addsitedir(item.value)

    with tempfile.TemporaryDirectory(prefix="hermes-config-check-") as tmp:
        isolated_env = {
            "HOME": tmp,
            "HERMES_HOME": tmp,
            "XDG_CONFIG_HOME": tmp,
            "XDG_CACHE_HOME": tmp,
            "PATH": os.environ.get("PATH", ""),
        }
        if len(sys.argv) > 3:
            isolated_env["HERMES_BUNDLED_LOCALES"] = str(Path(sys.argv[3]).resolve())
        with patch.dict(os.environ, isolated_env, clear=True):
            Path(tmp, "config.yaml").write_text(json.dumps(cfg))
            from gateway.config import Platform, load_gateway_config
            from gateway.display_config import resolve_display_setting
            from gateway.slash_commands import GatewaySlashCommandsMixin

            # Exercise the installed gateway parser and Telegram adapter, so
            # misspelled or misplaced options cannot silently pass validation.
            from plugins.platforms.telegram.adapter import TelegramAdapter
            from telegram import Bot

            gateway = load_gateway_config()
            assert gateway.streaming.enabled
            assert gateway.streaming.transport == "draft"
            for key, value in {
                "streaming": True,
                "cleanup_progress": True,
                "tool_progress": "new",
                "notifications": "important",
            }.items():
                assert resolve_display_setting(cfg, "telegram", key) == value
            assert not cfg["display"]["runtime_footer"]["enabled"]
            adapter = TelegramAdapter(gateway.platforms[Platform.TELEGRAM])
            assert adapter._reactions_enabled()
            assert adapter._link_preview_kwargs()["link_preview_options"].is_disabled
            assert adapter._notification_kwargs({}) == {"disable_notification": True}
            assert adapter._notification_kwargs({"notify": True}) == {}
            assert callable(getattr(Bot, "send_message_draft", None))
            draft = AsyncMock(return_value=True)
            adapter._bot = SimpleNamespace(send_message_draft=draft)
            assert adapter.supports_draft_streaming("dm")
            assert not adapter.supports_draft_streaming("group")
            result = asyncio.run(adapter.send_draft("123456", 1, "Synthetic preview"))
            assert result.success and result.message_id is None
            assert draft.await_count == 1
            assert draft.call_args.kwargs["text"] == "Synthetic preview"
            print("Telegram draft transport and display behavior: PASS")

            # Rich previews and finals must reach the native API with the
            # table intact, rather than silently falling back to plain text.
            assert adapter._rich_messages_enabled and adapter._rich_drafts_enabled
            assert inspect.iscoroutinefunction(Bot.do_api_request)
            rich_api = AsyncMock(side_effect=[True, {"message_id": 42}])
            adapter._bot.do_api_request = rich_api
            table = "| Item | Value |\n| --- | --- |\n| Example | 42 |"
            result = asyncio.run(adapter.send_draft("123456", 2, table))
            assert result.success and result.message_id is None
            assert rich_api.call_args.args[0] == "sendRichMessageDraft"
            assert draft.await_count == 1
            assert adapter._should_attempt_rich(table)
            result = asyncio.run(adapter._try_send_rich("123456", table, None, {"notify": True}))
            assert result.success and result.message_id == "42"
            assert rich_api.call_args.args[0] == "sendRichMessage"
            for call in rich_api.call_args_list:
                payload = call.kwargs["api_kwargs"]
                assert "| Example | 42 |" in json.dumps(payload["rich_message"])
            assert rich_api.call_args.kwargs["api_kwargs"]["link_preview_options"]["is_disabled"]
            print("Telegram native rich drafts and final messages: PASS")

            entry = SimpleNamespace(
                session_key="synthetic-session", session_id="synthetic-id",
                created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 1),
                last_prompt_tokens=1000,
            )
            runner = GatewaySlashCommandsMixin()
            runner.async_session_store = SimpleNamespace(get_or_create_session=AsyncMock(return_value=entry))
            runner.adapters = {Platform.TELEGRAM: None}
            runner._running_agents = {entry.session_key: SimpleNamespace(
                model=cfg["model"]["default"], provider=cfg["model"]["provider"],
                context_compressor=SimpleNamespace(last_prompt_tokens=1000, context_length=10000),
            )}
            runner._queue_depth = lambda *args, **kwargs: 2
            runner._session_db = SimpleNamespace(
                get_session_title=AsyncMock(return_value="Synthetic title"),
                get_session=AsyncMock(return_value={"input_tokens": 120, "output_tokens": 30}),
                get_dominant_session_model_route=AsyncMock(return_value={}),
            )
            event = SimpleNamespace(source=SimpleNamespace(platform=Platform.TELEGRAM))
            status = asyncio.run(runner._handle_status_command(event))
            assert "gateway.status." not in status, status
            for expected_value in ["synthetic-id", "Synthetic title", cfg["model"]["default"], "150", "1,000"]:
                assert expected_value in status, status
            print("Telegram status rendering: PASS")

            from hermes_cli.tools_config import _get_platform_tools

            expected = {"web", "terminal", "file", "memory", "session_search", "todo"}
            assert set(cfg["platform_toolsets"].get("cron", [])) == expected
            # Hermes expands todo to the kanban alias as well.
            assert _get_platform_tools(cfg, "cron") == expected | {"kanban"}
            print("Scheduled tool scope: PASS")

            from tools import web_tools
            from plugins.web.firecrawl import provider

            assert cfg["web"]["extract_backend"] == "firecrawl"
            assert provider._get_direct_firecrawl_config()[0] == "keyless"
            assert not provider._use_keyless_ring()
            response = Mock()
            response.json.return_value = {
                "success": True,
                "data": {"markdown": "Synthetic page text", "metadata": {}},
            }
            with (
                patch.object(web_tools, "async_is_safe_url", new=AsyncMock(return_value=True)),
                patch.object(provider, "is_safe_url", return_value=True),
                patch.object(provider.httpx, "post", return_value=response) as post,
            ):
                result = json.loads(asyncio.run(web_tools.web_extract_tool(["https://example.test/"])))
                assert not result.get("error"), result
                assert "Synthetic page text" in json.dumps(result), result
                assert post.call_count == 1
                assert post.call_args.args[0].endswith("/v2/scrape")
                assert not any(key.lower() == "authorization" for key in post.call_args.kwargs["headers"])
            print("Anonymous extraction dispatch: PASS")


if __name__ == "__main__":
    main()

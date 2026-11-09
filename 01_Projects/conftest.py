"""Shared test setup. / Общая настройка тестов."""
import sys

import pytest


@pytest.fixture(autouse=True)
def _fresh_assistant_route_state():
    """The assistant router remembers failing providers and the network for a while; every test starts clean.
    Маршрутизатор ассистента помнит упавших провайдеров и сеть; каждый тест начинается с чистого состояния."""
    module = sys.modules.get("orchestrator")
    if module is not None:
        module.assistant_cooldowns.clear()
        getattr(module._assistant_network_ok, "forget", lambda: None)()
    yield

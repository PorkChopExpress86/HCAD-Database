"""Simple tracing utility wrapping OpenTelemetry with graceful degradation.

Usage:
    from tracing import trace_span, get_tracer

    @trace_span()  # span name defaults to function name
    def my_function(...):
        ...

Environment variables influencing behavior:
    OTEL_TRACES_ENABLED=true|false (default true if opentelemetry installed)
    OTEL_SERVICE_NAME=<service name string> (default: hcad-data-pipeline)
    OTEL_EXPORTER_OTLP_ENDPOINT=<OTLP http(s) endpoint> (optional)

If opentelemetry is not installed or disabled, decorators become no-ops.
"""

from __future__ import annotations

import os
from typing import Any, Callable, Optional

_TRACER = None

try:
    import importlib

    # Import opentelemetry modules dynamically to avoid static-analysis import errors
    trace = importlib.import_module("opentelemetry.trace")
    _status_mod = importlib.import_module("opentelemetry.trace")
    Status = getattr(_status_mod, "Status")
    StatusCode = getattr(_status_mod, "StatusCode")
    Resource = importlib.import_module("opentelemetry.sdk.resources").Resource
    TracerProvider = importlib.import_module("opentelemetry.sdk.trace").TracerProvider
    _export_mod = importlib.import_module("opentelemetry.sdk.trace.export")
    BatchSpanProcessor = getattr(_export_mod, "BatchSpanProcessor")
    ConsoleSpanExporter = getattr(_export_mod, "ConsoleSpanExporter")
    try:
        OTLPSpanExporter = importlib.import_module(
            "opentelemetry.exporter.otlp.proto.http.trace_exporter"
        ).OTLPSpanExporter
    except Exception:  # pragma: no cover
        OTLPSpanExporter = None  # type: ignore

    _ENABLED = os.getenv("OTEL_TRACES_ENABLED", "true").lower() == "true"
    if _ENABLED:
        service_name = os.getenv("OTEL_SERVICE_NAME", "hcad-data-pipeline")
        resource = Resource.create({"service.name": service_name})
        provider = TracerProvider(resource=resource)
        # Console exporter always (helpful locally)
        provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
        endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
        if endpoint and OTLPSpanExporter is not None:
            try:
                provider.add_span_processor(
                    BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint))
                )
            except Exception:
                pass
        trace.set_tracer_provider(provider)
        _TRACER = trace.get_tracer(service_name)
except Exception:  # pragma: no cover - any failure -> no-op tracer
    _TRACER = None

    # Provide lightweight stubs to satisfy linters/type checkers
    class _StatusStub:  # type: ignore
        def __init__(self, *_a, **_k):
            pass

    class _StatusCodeStub:  # type: ignore
        ERROR = "ERROR"

    Status = _StatusStub  # type: ignore
    StatusCode = _StatusCodeStub  # type: ignore


def get_tracer():
    """Return active tracer or None if tracing disabled."""
    return _TRACER


def trace_span(name: Optional[str] = None):
    """Decorator to wrap a function in a span (no-op if tracing disabled)."""

    def decorator(fn: Callable):
        span_name = name or fn.__name__

        def wrapper(*args, **kwargs):
            tracer = get_tracer()
            if tracer is None:
                return fn(*args, **kwargs)
            with tracer.start_as_current_span(span_name) as span:
                # Optional simple attributes (avoid large payloads)
                try:
                    span.set_attribute("code.function", fn.__name__)
                except Exception:
                    pass
                try:
                    result = fn(*args, **kwargs)
                    return result
                except Exception as e:  # record and re-raise
                    if span is not None and Status is not None:
                        try:
                            span.record_exception(e)
                            span.set_status(Status(StatusCode.ERROR, str(e)))
                        except Exception:
                            pass
                    raise

        wrapper.__name__ = fn.__name__
        wrapper.__doc__ = fn.__doc__
        wrapper.__qualname__ = fn.__qualname__
        return wrapper

    return decorator


class span_context:
    """Context manager for ad-hoc spans.

    Example:
        with span_context("bulk_process"):
            ...
    """

    def __init__(self, name: str):
        self._name = name
        self._span = None

    def __enter__(self):
        tracer = get_tracer()
        if tracer is not None:
            self._span = tracer.start_span(self._name)
            return self._span
        return None

    def __exit__(self, exc_type, exc, tb):
        if self._span is not None:
            if exc is not None and Status is not None:
                try:
                    self._span.record_exception(exc)
                    self._span.set_status(Status(StatusCode.ERROR, str(exc)))
                except Exception:
                    pass
            try:
                self._span.end()
            except Exception:
                pass
        return False  # never suppress exceptions

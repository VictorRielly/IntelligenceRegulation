"""Explicit runtime selection for the guarded service; no fallback between modes."""
from . import config
from .classifier_cli import require


def runtime_for(kind=None):
    kind = config.prover_mode() if kind is None else kind
    if kind == 'shieldstral-fast':
        from . import shieldstral_fast_runtime
        return shieldstral_fast_runtime
    require(kind == 'shieldstral-fast-w16r2', 'unknown resident classifier mode')
    from .w16r2_runtime import Runtime
    return Runtime()

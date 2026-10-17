"""Public SC_SZC causal-mask dependency/evaluation prototype.

Native data axes are MSB-first (head_slot, t, j); terminal extension rounds
are appended after the data sumcheck, not interleaved in its table. This
module contains no witness, transcript, RNG, PCS or native refusal changes.
Unsupported metadata declines specialization; caller keeps scalar fallback.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class MaskLayout:
    head_slots: int
    token_extent: int
    true_heads: int
    true_tokens: int
    main_rounds: int
    extension_rounds: int = 1
    axes: tuple = ('head', 't', 'j')
    split: str = 'msb'
    extension_endpoint: str = 'zero'
    mask_rule: str = 'j_le_t_all_padded_heads_and_positions'


def dependency(layout):
    """Conservative structural dependence, independent of challenge values.

    False guarantees a zero difference for every paired row after any prefix
    of field folds. True permits a zero difference due to specialization.
    This metadata must come from the trusted constructor, never a receipt.
    """
    if not isinstance(layout, MaskLayout):
        return None
    h, t = layout.head_slots, layout.token_extent
    if any(type(v) is not int or v <= 0 or v & (v-1) for v in (h,t)):
        return None
    if any(type(v) is not int for v in (layout.true_heads,layout.true_tokens,
                                        layout.main_rounds,layout.extension_rounds)):
        return None
    if not (0 < layout.true_heads <= h and 0 < layout.true_tokens <= t):
        return None
    lh, lt = h.bit_length()-1, t.bit_length()-1
    if (layout.axes != ('head','t','j') or layout.split != 'msb' or
        layout.extension_endpoint != 'zero' or
        layout.mask_rule != 'j_le_t_all_padded_heads_and_positions' or
        layout.main_rounds != lh+2*lt or layout.extension_rounds != 1):
        return None
    return (False,)*lh + (True,)*(2*lt) + (True,)


def round0_mask_active(layout, pad_on, round_index=0):
    deps = dependency(layout)
    if (deps is None or type(pad_on) is not bool or pad_on or
        type(round_index) is not int or round_index != 0 or
        layout.main_rounds == 0):
        return None
    return deps[0]


def compare_mle(t_point, j_point, one):
    """Multilinear extension of j <= t via a two-state comparator.

    Every bit occurs once in a factor. No Boolean-only substitution is used.
    At unequal leading bits t=1,j=0 wins; equal bits defer to the suffix.
    """
    if len(t_point) != len(j_point):
        raise ValueError('point shape')
    le = one
    for t,j in zip(reversed(t_point),reversed(j_point)):
        same = (one-t)*(one-j)+t*j
        le = t*(one-j)+same*le
    return le


def mask_mle(layout, point, extensions, one):
    if dependency(layout) is None:
        raise ValueError('unsupported public metadata: scalar fallback')
    if len(point) != layout.main_rounds or len(extensions) != 1:
        raise ValueError('point shape')
    lh = layout.head_slots.bit_length()-1
    lt = layout.token_extent.bit_length()-1
    value = compare_mle(point[lh:lh+lt],point[lh+lt:],one)
    # Native public tables have ZERO at the terminal extension endpoint.
    return value*(one-extensions[0])

# Native dispatch audit

ROM SHA256: `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`

Pointer records: 291; unique targets: 142

| Classification | Count |
|---|---:|
| AMBIGUOUS | 11 |
| COVERED | 131 |

Static candidates are not execution coverage. MISSING_VALID uses a verified ROM pointer plus a boundary immediately after RTS or unconditional BRA. No game.toml edit is automatic.

A4 at `$035DF8` is assigned `$007760` or `$007B76` in generated `$035D62`; both are dispatched.

## Unresolved candidates

- 0x041D0E: AMBIGUOUS — no independently verified entry boundary (OR_DIV (A2))
- 0x041D12: AMBIGUOUS — no independently verified entry boundary (OR_DIV (A3))
- 0x0431E0: AMBIGUOUS — no independently verified entry boundary (OR_DIV (A1)+)
- 0x0431E6: AMBIGUOUS — no independently verified entry boundary (OR_DIV indexed(A0,0x8196))
- 0x043296: AMBIGUOUS — no independently verified entry boundary (OR_DIV indexed(A3,0x82F4))
- 0x0432DA: AMBIGUOUS — no independently verified entry boundary (OR_DIV indexed(A7,0x8297))
- 0x0432E0: AMBIGUOUS — no independently verified entry boundary (OR_DIV -(A5))
- 0x0432F6: AMBIGUOUS — no independently verified entry boundary (OR_DIV indexed(A1,0x829D))
- 0x043300: AMBIGUOUS — no independently verified entry boundary (OR_DIV -(A5))
- 0x043490: AMBIGUOUS — no independently verified entry boundary (OR_DIV A0)
- 0x043498: AMBIGUOUS — no independently verified entry boundary (OR_DIV -31996(A2))

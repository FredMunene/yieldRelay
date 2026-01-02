# Debug Log

Append entries whenever you hit an error, apply a significant fix, or uncover a non-obvious behavior. Follow the template below (timestamps in UTC):

```markdown
## [YYYY-MM-DD HH:MM] <Short Title>

**Context**
- Where it happened (file, function, scenario).

**Error / Symptom**
- Exact revert message, stack trace, or incorrect behavior.

**Root Cause**
- What was actually wrong.

**Fix / Troubleshooting Path**
- Steps taken and reasoning.

**Lesson Learned**
- How to avoid it next time.

**References**
- [Link to external docs, Etherscan, etc.]
```

> Always include direct URLs when referencing third-party documentation (ERC-4626, Aave v3, Octant v2, etc.).

## [2025-11-07 23:31] Forge compile blocked by `mcopy`

**Context**
- Running `forge test` after adding vault/router/strategy implementations and mocks.

**Error / Symptom**
- Solidity compiler threw `Function "mcopy" not found` originating from `openzeppelin-contracts/contracts/utils/Memory.sol`.

**Root Cause**
- We initially vendored OpenZeppelin v5.0.2, which expects a toolchain with the new Yul `mcopy` builtin enabled. The environment was lagging on an older Foundry bundle that couldn’t compile those sources reliably.

**Fix / Troubleshooting Path**
- Upgraded Foundry via `foundryup` to pull the latest binaries (which adds `svm` and modern solc downloads).
- To stay unblocked without relying on the newer Memory helpers, pinned the OpenZeppelin submodule to `v4.9.5`, which uses the pre-`mcopy` implementations compatible with our current toolchain.
- Regenerated remappings/import paths accordingly and re-ran `forge test` successfully.

**Lesson Learned**
- Capture third-party dependency versions explicitly and prefer stable tags that align with the available compiler toolchain in constrained environments.

**References**
- [OpenZeppelin Contracts Releases](https://github.com/OpenZeppelin/openzeppelin-contracts/releases)

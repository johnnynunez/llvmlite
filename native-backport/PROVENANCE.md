Isolated experimental backport; not an upstream release. No Isaac pins modified.
Backports native build selection from numba/llvmlite#1435, VS2026 selection, and MCJIT small code model + case-insensitive LMM selection from #1427. Requires LLVM20.1.8, NOT LLVM22/23. LLVM20 already has the Windows FrameLowering predicate fixed in LLVM22 by #1439.
Native build/runtime validation is a separate gate. Versioneer generates a PEP440 local commit suffix.

"""Pre-build regressions for the legacy backport, independent of LLVM."""
import ast
import importlib.util
from pathlib import Path
import platform
import sys
import unittest
from unittest.mock import patch

ROOT=Path(sys.argv.pop(1)).resolve()
class BackportContract(unittest.TestCase):
    def test_native_arm64_generator(self):
        with patch.object(sys,'platform','win32'), patch.object(platform,'machine',return_value='ARM64'):
            spec=importlib.util.spec_from_file_location('ffi_build_probe',ROOT/'ffi/build.py')
            mod=importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            with patch.object(mod,'try_cmake'):
                generator=mod.find_windows_generator()
        self.assertEqual(generator[1],'ARM64')

    def test_windows_uppercase_arm64_uses_lmm(self):
        tree=ast.parse((ROOT/'llvmlite/binding/executionengine.py').read_text())
        fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='create_mcjit_compiler')
        assign=next(n for n in ast.walk(fn) if isinstance(n,ast.Assign) and any(isinstance(x,ast.Name) and x.id=='use_lmm' for x in n.targets))
        expression=compile(ast.Expression(assign.value),'<actual use_lmm expression>','eval')
        with patch.object(platform,'machine',return_value='ARM64'):
            self.assertTrue(eval(expression,{'platform':platform}))

if __name__=='__main__': unittest.main()

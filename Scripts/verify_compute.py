#!/usr/bin/env python3
"""Compile an optimized macOS Metal/CPU parity runner (requires Xcode and Metal)."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='optics-compute-') as temporary:
    executable = Path(temporary) / 'verify'
    sources = sorted((root / 'Packages/OpticsPhysics/Sources/OpticsPhysics').glob('*.swift'))
    subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', *map(str, sources),
                    str(root / 'Scripts/verify_compute.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable), str(root / 'RealityOpticsShaderLab/Rendering/OpticsLUT.metal')], check=True)

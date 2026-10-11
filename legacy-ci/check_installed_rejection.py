import json,subprocess,sys
from pathlib import Path
p=subprocess.run([sys.executable,"-c","import numpy; print(numpy.__version__); import numba"],capture_output=True,text=True)
Path(sys.argv[1]).write_text(json.dumps(dict(returncode=p.returncode,stdout=p.stdout,stderr=p.stderr),indent=2))
assert p.returncode != 0 and "Numba needs NumPy 2.4 or less. Got NumPy 2.5." in p.stderr

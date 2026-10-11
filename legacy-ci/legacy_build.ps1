$ErrorActionPreference='Stop'
$stage="$env:RUNNER_TEMP\legacy-stage"
New-Item -ItemType Directory -Force $stage | Out-Null
$src="$env:RUNNER_TEMP\llvm-project-20.1.8.src"
$url='https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/llvm-project-20.1.8.src.tar.xz'
$archive="$env:RUNNER_TEMP\llvm20.tar.xz"
Invoke-WebRequest $url -OutFile $archive
$sha=(Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
if ($sha -ne '6898f963c8e938981e6c4a302e83ec5beb4630147c7311183cf61069af16333d') {throw 'LLVM archive mismatch'}
"LLVM20_SOURCE_SHA256=$sha" | Out-File "$stage\llvm-source.txt"
tar xf $archive -C $env:RUNNER_TEMP
if ($LASTEXITCODE -ne 0) {throw 'extract failed'}
# Reuse merged Oryon fix; no 22.x ABI substitution. LLVM20 already has the
# correct Windows predicate in AArch64FrameLowering (do not double-apply).
git -C $src apply --check "$env:GITHUB_WORKSPACE\harness\legacy-ci\oryon.patch"
if ($LASTEXITCODE -ne 0) {throw 'Oryon patch not applicable'}
git -C $src apply "$env:GITHUB_WORKSPACE\harness\legacy-ci\oryon.patch"
if ($LASTEXITCODE -ne 0) {throw 'Oryon patch failed'}
$build="$env:RUNNER_TEMP\llvm20-build"
$install="$env:RUNNER_TEMP\llvm20-install"
cmake -S "$src\llvm" -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$install" -DLLVM_ENABLE_RTTI=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_ENABLE_DIA_SDK=OFF '-DLLVM_ENABLE_PROJECTS=lld;compiler-rt' -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILTINS_HIDE_SYMBOLS=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_CRT=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_GWP_ASAN=OFF -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_INCLUDE_TESTS=OFF
if ($LASTEXITCODE -ne 0) {throw 'LLVM configure failed'}
Copy-Item "$build\CMakeCache.txt" "$stage\LLVM-CMakeCache.txt"
cmake --build $build --parallel 2
if ($LASTEXITCODE -ne 0) {throw 'LLVM build failed'}
cmake --install $build
if ($LASTEXITCODE -ne 0) {throw 'LLVM install failed'}
& "$install\bin\llvm-config.exe" --version --targets-built | Out-File "$stage\llvm-config.txt"
& "$install\bin\llc.exe" "$env:GITHUB_WORKSPACE\harness\legacy-ci\test-frame-record-win-arm64.ll" -o "$stage\frame-record.s"
if ($LASTEXITCODE -ne 0) {throw 'LLVM frame regression failed'}
$env:CMAKE_PREFIX_PATH=$install
$env:LLVMLITE_PACKAGE_FORMAT='wheel'
Set-Location "$env:GITHUB_WORKSPACE\llvmlite-source"
python -m build --wheel --no-isolation
if ($LASTEXITCODE -ne 0) {throw 'legacy llvmlite build failed'}
New-Item -ItemType Directory -Force wheel_temp | Out-Null
Move-Item dist\*.whl wheel_temp\
$original=(Get-ChildItem wheel_temp\*.whl).FullName
python -m delvewheel repair --analyze-existing -w dist $original
if ($LASTEXITCODE -ne 0) {throw 'repair failed'}
Copy-Item dist\*.whl $stage
$wheel=(Get-ChildItem dist\*.whl).FullName
python -m pip install --no-deps $wheel
if ($LASTEXITCODE -ne 0) {throw 'install failed'}
Set-Location "$env:GITHUB_WORKSPACE\numba-source"
python -m build --wheel --no-isolation
if ($LASTEXITCODE -ne 0) {throw 'legacy Numba build failed'}
Copy-Item dist\*.whl $stage
$wheel=(Get-ChildItem dist\*.whl).FullName
python -m pip install --no-deps $wheel
if ($LASTEXITCODE -ne 0) {throw 'install failed'}
Set-Location $env:GITHUB_WORKSPACE
python harness\native-ci\wheel_audit.py $stage "$stage\wheel-audit.json"
if ($LASTEXITCODE -ne 0) {throw 'PE or RECORD audit failed'}
python harness\native-ci\runtime_probe.py "$stage\runtime-default.json"
if ($LASTEXITCODE -ne 0) {throw 'legacy native runtime failed'}
$env:NUMBA_CPU_NAME='generic'
python harness\native-ci\runtime_probe.py "$stage\runtime-generic.json"
if ($LASTEXITCODE -ne 0) {throw 'legacy generic runtime failed'}
python -m pip check
if ($LASTEXITCODE -ne 0) {throw 'metadata closure failed'}

# -*- mode: python ; coding: utf-8 -*-
import importlib
import os
import pathlib
import platform
import site
import sysconfig

from PyInstaller.utils.hooks import collect_submodules, copy_metadata

THIS_IS_WINDOWS = platform.system().lower().startswith("win")
THIS_IS_MAC = platform.system().lower().startswith("darwin")

ROOT = pathlib.Path(SPECPATH).absolute().parent

# Find chia package location - it's installed as a dependency
chia_package = None
for site_dir in site.getsitepackages():
    potential_chia = pathlib.Path(site_dir) / "chia"
    if potential_chia.exists():
        chia_package = potential_chia
        break

if chia_package is None:
    # Try user site packages
    user_site = site.getusersitepackages()
    if user_site:
        potential_chia = pathlib.Path(user_site) / "chia"
        if potential_chia.exists():
            chia_package = potential_chia

if chia_package is None:
    raise RuntimeError("Could not find chia package. Make sure chia-blockchain is installed.")

CHIA_ROOT = chia_package.parent

keyring_imports = collect_submodules("keyring.backends")

# keyring uses entrypoints to read keyring.backends from metadata file entry_points.txt.
keyring_datas = copy_metadata("keyring")[0]

version_data = [
    copy_metadata(name)[0]
    for name in ["chia-blockchain", "chiapos"]
]

block_cipher = None

SERVERS = [
    "data_layer",
    "wallet",
    "full_node",
    "harvester",
    "farmer",
    "introducer",
    "timelord",
]

if THIS_IS_WINDOWS:
    hidden_imports_for_windows = ["win32timezone", "win32cred", "pywintypes", "win32ctypes.pywin32"]
else:
    hidden_imports_for_windows = []

hiddenimports = [
    *collect_submodules("chia"),
    *keyring_imports,
    *hidden_imports_for_windows,
]

binaries = []

if os.path.exists(f"{ROOT}/madmax/chia_plot"):
    binaries.extend([
        (
            f"{ROOT}/madmax/chia_plot",
            "madmax"
        )
    ])

if os.path.exists(f"{ROOT}/madmax/chia_plot_k34",):
    binaries.extend([
        (
            f"{ROOT}/madmax/chia_plot_k34",
            "madmax"
        )
    ])

if os.path.exists(f"{ROOT}/bladebit/bladebit"):
    binaries.extend([
        (
            f"{ROOT}/bladebit/bladebit",
            "bladebit"
        )
    ])

if os.path.exists(f"{ROOT}/bladebit/bladebit_cuda"):
    binaries.extend([
        (
            f"{ROOT}/bladebit/bladebit_cuda",
            "bladebit"
        )
    ])

if THIS_IS_WINDOWS:
    chia_mod = importlib.import_module("chia")
    dll_paths = pathlib.Path(sysconfig.get_path("platlib")) / "*.dll"

    binaries = [
        (
            dll_paths,
            ".",
        ),
        (
            "C:\\Windows\\System32\\msvcp140.dll",
            ".",
        ),
        (
            "C:\\Windows\\System32\\vcruntime140_1.dll",
            ".",
        ),
        (
            f"{ROOT}\\madmax\\chia_plot.exe",
            "madmax"
        ),
        (
            f"{ROOT}\\madmax\\chia_plot_k34.exe",
            "madmax"
        ),
        (
            f"{ROOT}\\bladebit\\bladebit.exe",
            "bladebit"
        ),
        (
            f"{ROOT}\\bladebit\\bladebit_cuda.exe",
            "bladebit"
        ),
    ]


datas = []

datas.append((f"{chia_package}/util/english.txt", "chia/util"))
datas.append((f"{chia_package}/util/initial-config.yaml", "chia/util"))
for path in sorted({path.parent for path in chia_package.rglob("*.hex")}):
    datas.append((f"{path}/*.hex", path.relative_to(CHIA_ROOT)))
datas.append((f"{chia_package}/ssl/*", "chia/ssl"))
datas.extend(version_data)

pathex = []


def add_binary(name, path_to_script, collect_args):
    analysis = Analysis(
        [path_to_script],
        pathex=pathex,
        binaries=binaries,
        datas=datas,
        hiddenimports=hiddenimports,
        hookspath=[],
        runtime_hooks=[],
        excludes=[],
        win_no_prefer_redirects=False,
        win_private_assemblies=False,
        cipher=block_cipher,
        noarchive=False,
    )

    binary_pyz = PYZ(analysis.pure, analysis.zipped_data, cipher=block_cipher)

    binary_exe = EXE(
        binary_pyz,
        analysis.scripts,
        [],
        exclude_binaries=True,
        name=name,
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
    )

    collect_args.extend(
        [
            binary_exe,
            analysis.binaries,
            analysis.zipfiles,
            analysis.datas,
        ]
    )


COLLECT_ARGS = []

# Find the chia entry point scripts
chia_cmds = chia_package / "cmds" / "chia.py"
chia_daemon = chia_package / "daemon" / "server.py"

add_binary("chia", str(chia_cmds), COLLECT_ARGS)
add_binary("daemon", str(chia_daemon), COLLECT_ARGS)

for server in SERVERS:
    server_script = chia_package / server / f"start_{server}.py"
    add_binary(f"start_{server}", str(server_script), COLLECT_ARGS)

add_binary("start_crawler", str(chia_package / "seeder" / "start_crawler.py"), COLLECT_ARGS)
add_binary("start_seeder", str(chia_package / "seeder" / "dns_server.py"), COLLECT_ARGS)
add_binary("start_data_layer_http", str(chia_package / "data_layer" / "data_layer_server.py"), COLLECT_ARGS)
add_binary("start_data_layer_s3_plugin", str(chia_package / "data_layer" / "s3_plugin_service.py"), COLLECT_ARGS)
add_binary("timelord_launcher", str(chia_package / "timelord" / "timelord_launcher.py"), COLLECT_ARGS)
add_binary("start_simulator", str(chia_package / "simulator" / "start_simulator.py"), COLLECT_ARGS)

COLLECT_KWARGS = dict(
    strip=False,
    upx_exclude=[],
    name="daemon",
)

coll = COLLECT(*COLLECT_ARGS, **COLLECT_KWARGS)

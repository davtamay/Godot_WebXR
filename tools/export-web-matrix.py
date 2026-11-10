"""Export web template variants from one fresh shared asset bake.

Example: python tools/export-web-matrix.py --editor C:/engine/bin/godot.windows.editor.x86_64.console.exe --output C:/exports/matrix
Do not edit export_presets.cfg concurrently: template overrides are temporary
and its original bytes are restored even if an export fails. Old generated
caches are retained under .godot for inspection, never removed with source files.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--editor', type=Path, required=True)
parser.add_argument('--templates-dir', type=Path)
parser.add_argument('--tint', type=Path)
parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1] / 'demo')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--presets', nargs='+', default=['Web', 'WebThreads'])
args = parser.parse_args()
editor, project, output = args.editor.resolve(), args.project.resolve(), args.output.resolve()
templates = (args.templates_dir or editor.parent).resolve()
presets_path = project / 'export_presets.cfg'
original = presets_path.read_bytes()
text = original.decode('utf-8')
sections = dict(re.findall(r'^\[([^\]]+)\]\s*\n(.*?)(?=^\[|\Z)', text, re.M | re.S))
for name in args.presets:
    matches = [section for section, body in sections.items()
               if re.fullmatch(r'preset\.\d+', section) and re.search(r'^name="' + re.escape(name) + r'"\s*$', body, re.M)]
    if len(matches) != 1:
        raise ValueError(f'Expected one preset named {name}')
    section = matches[0] + '.options'
    threaded = re.search(r'^variant/thread_support=true\s*$', sections[section], re.M) is not None
    suffix = '' if threaded else '.nothreads'
    template = templates / f'godot.web.template_release.wasm32{suffix}.zip'
    if not template.is_file():
        raise FileNotFoundError(template)
    replacement, count = re.subn(r'^custom_template/release="[^"]*"',
                                f'custom_template/release="{template.as_posix()}"', sections[section], flags=re.M)
    if count != 1:
        raise ValueError(f'Missing template setting in {section}')
    pattern = re.compile(r'(^\[' + re.escape(section) + r'\]\s*\n)(.*?)(?=^\[|\Z)', re.M | re.S)
    text, count = pattern.subn(lambda match: match[1] + replacement, text)
    assert count == 1

output.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
# Preserve an explicitly supplied short drive alias on Windows.
env['GODOT_TINT_PATH'] = str((args.tint or editor.parent / ('tint.exe' if os.name == 'nt' else 'tint')).absolute())
try:
    presets_path.write_bytes(text.encode('utf-8'))
    # Clear the previous engine's bake ONCE. Threading changes the template,
    # not the scene data; a second cold bake regenerates scene identifiers.
    cache_root = (project / '.godot').resolve()
    if not cache_root.is_relative_to(project):
        raise ValueError('Project cache resolves outside the project directory')
    for name in ['exported', 'shader_cache']:
        source = cache_root / name
        archived = cache_root / f'{name}-before-matrix-{uuid.uuid4().hex[:8]}'
        if not source.resolve().is_relative_to(cache_root) or not archived.resolve().is_relative_to(cache_root):
            raise ValueError(f'Cache path escapes project cache: {source}')
        if source.exists():
            source.rename(archived)
    for name in args.presets:
        destination = output / name
        destination.mkdir(exist_ok=True)
        log_path = output / f'{name}.export.log'
        with log_path.open('w', encoding='utf-8') as log:
            result = subprocess.run([
                str(editor), '--xr-mode', 'off', '--path', str(project), '--verbose',
                '--export-release', name, str(destination / 'index.html')],
                env=env, stdout=log, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        log_text = log_path.read_text(encoding='utf-8', errors='replace')
        # The engine retries transient Tint process-launch errors. Reject an
        # exhausted retry budget, not an OS message followed by recovery.
        if result.returncode or any(error in log_text for error in ['Safe save failed', 'SCRIPT ERROR', 'Parse Error', 'WebGPU bake: could not start the Tint translator']):
            raise RuntimeError(f'Export {name} failed; see {log_path}')
        if not (destination / 'index.pck').is_file():
            raise RuntimeError(f'Export {name} did not produce a pack')
        print(f'Exported {name}: {destination}', flush=True)
        retries = log_text.count('Could not create child process:')
        if retries:
            print(f'{name}: {retries} compiler-launch retry message(s); verify the shader exclusion census.', flush=True)
finally:
    presets_path.write_bytes(original)
print('Restored original preset bytes. Run compare-thread-packs.py on the two exports.')

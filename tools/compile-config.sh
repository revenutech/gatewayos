#!/bin/sh
# =============================================================================
# KrakenD Flexible Configuration Compiler
# Compiles krakend.tmpl + partials + settings into a static JSON config.
# Used at Docker build time since FC doesn't work in CE runtime.
# =============================================================================
set -e

KRAKEND_DIR="${1:-/etc/krakend}"
ENV="${2:-dev}"
OUTPUT="${3:-/etc/krakend/krakend.json}"

SETTINGS="$KRAKEND_DIR/settings/${ENV}.json"
PARTIALS="$KRAKEND_DIR/partials"
TEMPLATES="$KRAKEND_DIR/templates"
TMPL="$KRAKEND_DIR/krakend.tmpl"

echo "Compiling: env=$ENV, settings=$SETTINGS, output=$OUTPUT"

# Use Python to do Go-template-like substitution
export KRAKEND_DIR ENV OUTPUT
python3 << 'PYEOF'
import os, re, json, sys

krakend_dir = os.environ["KRAKEND_DIR"]
env_name = os.environ["ENV"]
output = os.environ["OUTPUT"]

settings_file = f"{krakend_dir}/settings/{env_name}.json"
partials_dir = f"{krakend_dir}/partials"
templates_dir = f"{krakend_dir}/templates"
tmpl_file = f"{krakend_dir}/krakend.tmpl"

# Load settings
with open(settings_file) as f:
    settings = json.load(f)

# Load all partials
partials = {}
for f in sorted(os.listdir(partials_dir)):
    fp = os.path.join(partials_dir, f)
    if os.path.isfile(fp) and f.endswith('.tmpl'):
        with open(fp) as fh:
            partials[f] = fh.read()

# Load all templates (includes endpoint_*.tmpl and partial *.tmpl)
templates = {}
for f in sorted(os.listdir(templates_dir)):
    fp = os.path.join(templates_dir, f)
    if os.path.isfile(fp) and f.endswith('.tmpl'):
        with open(fp) as fh:
            templates[f] = fh.read()

# Read main template
with open(tmpl_file) as f:
    content = f.read()

# Phase 1: Replace {{ template "partials/xxx" . }} and {{ template "xxx.tmpl" . }}
all_templates = {}
all_templates.update(partials)
all_templates.update(templates)

def replace_templates(content, depth=0):
    if depth > 10:
        return content
    changed = True
    while changed:
        changed = False
        for name, body in all_templates.items():
            for pattern in [
                '{{ template "' + name + '" . }}',
                '{{ template "' + name + '" }}',
                '{{template "' + name + '" .}}',
                '{{template "' + name + '"}}',
            ]:
                if pattern in content:
                    content = content.replace(pattern, body)
                    changed = True
    return content

content = replace_templates(content)

# Phase 2: Replace {{ .key.subkey }} with settings values
def get_nested(d, path):
    for k in path:
        if isinstance(d, dict) and k in d:
            d = d[k]
        else:
            return None
    return d

def replace_var(match):
    path = match.group(1).strip().split('.')
    val = get_nested(settings, path)
    if val is None:
        return match.group(0)  # Keep original if not found
    if isinstance(val, bool):
        return 'true' if val else 'false'
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, str):
        return val
    return json.dumps(val)

# Handle {{ marshal .key }} — serialize to JSON
def replace_marshal(match):
    path = match.group(1).strip().split('.')
    val = get_nested(settings, path)
    if val is None:
        return match.group(0)
    return json.dumps(val)

content = re.sub(r'\{\{[\s]*marshal\s+\.([a-zA-Z0-9_.]+)[\s]*\}\}', replace_marshal, content)

# Handle {{ .key.subkey }}
content = re.sub(r'\{\{[\s]*\.([a-zA-Z0-9_.]+)[\s]*\}\}', replace_var, content)

# Phase 3: Handle {{ if .key }}...{{ else }}...{{ end }}
# A condicao e AVALIADA contra as settings. Antes esta fase devolvia sempre o
# ramo verdadeiro, o que tornava toda condicional decorativa — expose_docs:false
# em producao nao removia nada.
def _truthy(path):
    value = get_nested(settings, path.split("."))
    return value not in (None, False, 0, "", "false", "False", [], {})

def _if_else(m):
    return m.group(2) if _truthy(m.group(1)) else m.group(3)

def _if_only(m):
    return m.group(2) if _truthy(m.group(1)) else ""

content = re.sub(r'\{\{\s*if\s+\.([a-zA-Z0-9_.]+)\s*\}\}(.*?)\{\{\s*else\s*\}\}(.*?)\{\{\s*end\s*\}\}',
    _if_else, content, flags=re.DOTALL)
content = re.sub(r'\{\{\s*if\s+\.([a-zA-Z0-9_.]+)\s*\}\}(.*?)\{\{\s*end\s*\}\}',
    _if_only, content, flags=re.DOTALL)

# Phase 4: Remove remaining Go template directives
content = re.sub(r'\{\{[^}]*\}\}', '', content)

# Phase 5: Clean JSON
content = re.sub(r'\{\{/\*.*?\*/\}\}', '', content, flags=re.DOTALL)  # Go template comments
content = re.sub(r',\s*,', ',', content)  # double commas
content = re.sub(r'\{\s*,', '{', content)  # leading comma after {
content = re.sub(r'\[\s*,', '[', content)  # leading comma after [
content = re.sub(r',\s*([}\]])', r'\1', content)  # trailing comma before } or ]
# Multiple passes for nested cleanup
for _ in range(3):
    content = re.sub(r',\s*,', ',', content)
    content = re.sub(r'\{\s*,', '{', content)
    content = re.sub(r',\s*([}\]])', r'\1', content)

# Validate JSON
try:
    parsed = json.loads(content)
    with open(output, 'w') as f:
        json.dump(parsed, f, indent=2)
    print(f"Compiled successfully: {output} ({len(json.dumps(parsed))} bytes)")
except json.JSONDecodeError as e:
    print(f"WARNING: JSON validation failed: {e}", file=sys.stderr)
    with open(output, 'w') as f:
        f.write(content)
    print(f"Wrote raw output: {output}")
    sys.exit(1)
PYEOF

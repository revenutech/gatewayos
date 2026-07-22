#!/usr/bin/env python3
"""
OpenAPI 3.0 Spec Generator for KrakenD Gateway
Enterprise KrakenD equivalent: developer/openapi (export/serve)

Parses KrakenD endpoint JSON files and generates an OpenAPI 3.0.3 specification.
Supports Go template syntax stripping for parsing.

Usage:
    python generate.py --endpoints-dir ../../krakend/templates --output openapi.yaml
    python generate.py --endpoints-dir ../../krakend/templates --output openapi.json --format json
"""

import argparse
import json
import os
import re
import sys
import yaml


def strip_go_templates(content: str) -> str:
    """Remove Go template directives so JSON can be parsed."""
    # Remove {{ template "..." . }} lines
    content = re.sub(r'\{\{[^}]*\}\}\s*,?\s*', '', content)
    # Remove trailing commas before closing braces
    content = re.sub(r',\s*([}\]])', r'\1', content)
    # Remove _comment and _enterprise_equivalent fields
    content = re.sub(r'"_\w+":\s*"[^"]*"\s*,?\s*', '', content)
    return content


def parse_endpoint_file(filepath: str) -> list:
    """Parse a KrakenD endpoint JSON file, returning list of endpoint dicts."""
    with open(filepath, 'r') as f:
        content = f.read()

    cleaned = strip_go_templates(content)
    # Wrap in array if not already
    cleaned = cleaned.strip()
    if not cleaned.startswith('['):
        cleaned = f'[{cleaned}]'

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        print(f"  Warning: Could not parse {filepath}, skipping", file=sys.stderr)
        return []


def krakend_path_to_openapi(path: str) -> str:
    """Convert KrakenD path params to OpenAPI format: {id} stays, {path} stays."""
    return path


def extract_path_params(path: str) -> list:
    """Extract path parameters from endpoint path."""
    params = []
    for match in re.finditer(r'\{(\w+)\}', path):
        param_name = match.group(1)
        params.append({
            'name': param_name,
            'in': 'path',
            'required': True,
            'schema': {'type': 'string'},
            'description': f'Resource {param_name}'
        })
    return params


def infer_tag(endpoint_path: str) -> str:
    """Infer API tag from endpoint path."""
    parts = endpoint_path.strip('/').split('/')
    if len(parts) >= 2:
        resource = parts[1]
        # Map known resources to tags
        tag_map = {
            'postings': 'Ledger',
            'balances': 'Ledger',
            'settlements': 'Ledger',
            'reconciliation': 'Ledger',
            'pix': 'Payments',
            'ted': 'Payments',
            'boleto': 'Payments',
            'atm': 'Automation',
            'auth': 'Identity',
            'users': 'Identity',
            'admin': 'Admin',
            'onboarding': 'Onboarding',
            'accounts': 'Accounts',
            'finance': 'Finance',
            'my': 'Self-Service',
        }
        return tag_map.get(resource, resource.capitalize())
    return 'General'


def extract_roles(endpoint: dict) -> list:
    """Extract required roles from endpoint config."""
    extra = endpoint.get('extra_config', {})
    validator = extra.get('auth/validator', {})
    return validator.get('roles', [])


def build_operation(endpoint: dict) -> dict:
    """Build an OpenAPI operation from a KrakenD endpoint."""
    path = endpoint.get('endpoint', '/')
    method = endpoint.get('method', 'GET').lower()
    tag = infer_tag(path)
    roles = extract_roles(endpoint)

    operation = {
        'tags': [tag],
        'summary': f'{method.upper()} {path}',
        'operationId': f'{method}_{path.replace("/", "_").replace("{", "").replace("}", "").strip("_")}',
        'security': [{'BearerAuth': []}, {'ApiKeyAuth': []}],
        'responses': {
            '200': {'description': 'Successful response'},
            '401': {'description': 'Unauthorized — invalid or missing token'},
            '403': {'description': 'Forbidden — insufficient roles'},
            '429': {'description': 'Rate limit exceeded'},
            '503': {'description': 'Service unavailable — circuit breaker open'},
        }
    }

    # Path parameters
    params = extract_path_params(path)
    if params:
        operation['parameters'] = params

    # Query string support
    if endpoint.get('input_query_strings') == ['*']:
        operation.setdefault('parameters', []).append({
            'name': 'query',
            'in': 'query',
            'required': False,
            'schema': {'type': 'string'},
            'description': 'Query parameters (passthrough)'
        })

    # Request body for POST/PUT/PATCH
    if method in ('post', 'put', 'patch'):
        operation['requestBody'] = {
            'required': True,
            'content': {
                'application/json': {
                    'schema': {'type': 'object'}
                }
            }
        }

    # Document roles in description
    if roles:
        operation['description'] = f'Required roles: {", ".join(roles)}'

    return operation


def generate_spec(endpoints_dir: str) -> dict:
    """Generate complete OpenAPI spec from endpoint directory."""
    spec = {
        'openapi': '3.0.3',
        'info': {
            'title': 'Revenu Platform API',
            'description': (
                'API Gateway for the Revenu Platform.\n\n'
                'All endpoints require JWT authentication via Keycloak.\n'
                'Rate limiting is applied per-tenant via X-Tenant-ID header.\n\n'
                'Generated from KrakenD gateway configuration.'
            ),
            'version': '1.0.0',
            'contact': {
                'name': 'Revenu Platform Team',
            },
        },
        'servers': [
            {'url': 'https://api.revenu.com.br', 'description': 'Production'},
            {'url': 'https://api-staging.revenu.com.br', 'description': 'Staging'},
            {'url': 'http://localhost:8080', 'description': 'Local development'},
        ],
        'security': [{'BearerAuth': []}],
        'paths': {},
        'components': {
            'securitySchemes': {
                'BearerAuth': {
                    'type': 'http',
                    'scheme': 'bearer',
                    'bearerFormat': 'JWT',
                    'description': 'Keycloak JWT token (RS256)'
                },
                'ApiKeyAuth': {
                    'type': 'apiKey',
                    'in': 'header',
                    'name': 'X-API-Key',
                    'description': 'API key for M2M authentication'
                }
            },
            'parameters': {
                'TenantID': {
                    'name': 'X-Tenant-ID',
                    'in': 'header',
                    'required': True,
                    'schema': {'type': 'string'},
                    'description': 'Tenant identifier (from JWT or manual)'
                },
                'CorrelationID': {
                    'name': 'X-Correlation-ID',
                    'in': 'header',
                    'required': True,
                    'schema': {'type': 'string', 'format': 'uuid'},
                    'description': 'Request correlation ID for tracing'
                }
            }
        },
        'tags': [
            {'name': 'Ledger', 'description': 'LedgerOS — Postings, Balances, Settlements, Reconciliation'},
            {'name': 'Payments', 'description': 'Paymentos — PIX, TED, Boleto'},
            {'name': 'Automation', 'description': 'AtmOS — Automation workflows'},
            {'name': 'Identity', 'description': 'IdentityOS — Authentication and user management'},
            {'name': 'Admin', 'description': 'Administrative operations (ledger-admin only)'},
            {'name': 'Onboarding', 'description': 'OnboardOS — Customer onboarding'},
            {'name': 'Accounts', 'description': 'AccountOS — Account management'},
            {'name': 'Finance', 'description': 'FinanceOS — Financial operations'},
            {'name': 'Self-Service', 'description': 'Tenant/user-scoped self-service endpoints'},
            {'name': 'Health', 'description': 'Health check endpoints'},
        ]
    }

    # Parse all endpoint files
    for filename in sorted(os.listdir(endpoints_dir)):
        filepath = os.path.join(endpoints_dir, filename)
        if not (filename.startswith('endpoint_') and filename.endswith('.tmpl')) or os.path.isdir(filepath):
            continue

        print(f"  Parsing {filename}...", file=sys.stderr)
        endpoints = parse_endpoint_file(filepath)

        for ep in endpoints:
            path = ep.get('endpoint')
            method = ep.get('method', 'GET').lower()
            if not path:
                continue

            openapi_path = krakend_path_to_openapi(path)
            if openapi_path not in spec['paths']:
                spec['paths'][openapi_path] = {}

            spec['paths'][openapi_path][method] = build_operation(ep)

    return spec


def main():
    parser = argparse.ArgumentParser(description='Generate OpenAPI spec from KrakenD endpoints')
    parser.add_argument('--endpoints-dir', required=True, help='Path to KrakenD endpoints directory')
    parser.add_argument('--output', required=True, help='Output file path')
    parser.add_argument('--format', choices=['yaml', 'json'], default='yaml', help='Output format')
    args = parser.parse_args()

    if not os.path.isdir(args.endpoints_dir):
        print(f"Error: {args.endpoints_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    print("Generating OpenAPI spec...", file=sys.stderr)
    spec = generate_spec(args.endpoints_dir)

    with open(args.output, 'w') as f:
        if args.format == 'json':
            json.dump(spec, f, indent=2)
        else:
            yaml.dump(spec, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    path_count = len(spec['paths'])
    op_count = sum(len(methods) for methods in spec['paths'].values())
    print(f"Generated: {path_count} paths, {op_count} operations -> {args.output}", file=sys.stderr)


if __name__ == '__main__':
    main()

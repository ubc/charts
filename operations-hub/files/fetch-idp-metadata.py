#!/usr/bin/env python3
"""Fetch UBC IAM's SAML metadata at pod start.

Runs as an init container, deliberately not in the request path: the application
re-reads this file on every SAML request, and fetching there would put an external
dependency in the login path and hand whoever can spoof that host control of the
signing certificate.

Any failure falls back to a baseline copy so an IdP outage cannot take the
application down -- this app also offers local login, and failing closed would turn
an SSO outage into a total one. Exits non-zero only when nothing safe can be served.
"""

import os
import sys
import tempfile
import urllib.request

from onelogin.saml2.idp_metadata_parser import OneLogin_Saml2_IdPMetadataParser


def log(level, message):
    print(f'{level}: {message}', file=sys.stderr, flush=True)


def fetch(url, timeout):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read().decode('utf-8')


def validate(xml, expected_entity_id):
    """Validate with the parser the application itself uses.

    Acceptance here is therefore a guarantee of acceptance there, which a generic
    XML well-formedness check could not offer.
    """
    idp = OneLogin_Saml2_IdPMetadataParser.parse(xml).get('idp')
    if not idp:
        raise ValueError('no idp block in metadata')
    actual = idp.get('entityId')
    if actual != expected_entity_id:
        raise ValueError(
            f'entityId mismatch: got {actual!r}, expected {expected_entity_id!r}')
    return xml


def write_atomic(path, content):
    """Write via a temp file and rename, so a crash mid-write cannot leave a
    truncated document where the application expects valid XML."""
    directory = os.path.dirname(path) or '.'
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(handle, 'w') as out:
            out.write(content)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main():
    url = os.environ['IDP_METADATA_URL']
    entity_id = os.environ['IDP_ENTITY_ID']
    output = os.environ['IDP_OUTPUT_PATH']
    timeout = int(os.environ.get('IDP_FETCH_TIMEOUT', '15'))
    baseline = os.environ.get('IDP_BASELINE_PATH', '')

    try:
        xml = validate(fetch(url, timeout), entity_id)
    except Exception as exc:
        log('WARNING', f'IdP metadata fetch failed ({type(exc).__name__}: {exc})')
        if baseline and os.path.isfile(baseline):
            log('WARNING',
                f'using baseline at {baseline}; SSO may be running on stale metadata')
            with open(baseline) as source:
                write_atomic(output, source.read())
            return 0
        log('ERROR', 'fetch failed and no baseline is available; nothing safe to serve')
        return 1

    write_atomic(output, xml)
    log('INFO', f'IdP metadata fetched from {url}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

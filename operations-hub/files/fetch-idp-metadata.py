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
import urllib.parse
import urllib.request

from onelogin.saml2.idp_metadata_parser import OneLogin_Saml2_IdPMetadataParser


def log(level, message):
    print(f'{level}: {message}', file=sys.stderr, flush=True)


def fetch(url, timeout):
    """Fetch the metadata document, refusing anything that is not https.

    TLS plus the pinned entity id are the only integrity controls this design
    has -- UBC's metadata is unsigned. A bare string-prefix check is not enough
    (e.g. "https.evil.example" or a scheme-relative surprise), so the scheme is
    parsed properly and compared for exact equality. Raises rather than exits so
    this flows through the caller's existing failure path (WARNING + baseline
    fallback) instead of adding a second way for the script to stop.
    """
    scheme = urllib.parse.urlsplit(url).scheme
    if scheme != 'https':
        raise ValueError(f'refusing non-https URL scheme {scheme!r} for {url!r}')
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
    truncated document where the application expects valid XML.

    mkstemp() creates the temp file mode 0600 (owner-only). Widen it to 0644
    explicitly before the rename: os.replace() preserves whatever mode the temp
    file had, and this file's readability by the app container should be a
    stated property of this script, not an inherited tempfile default.
    """
    directory = os.path.dirname(path) or '.'
    os.makedirs(directory, exist_ok=True)
    handle, tmp = tempfile.mkstemp(dir=directory)
    try:
        os.fchmod(handle, 0o644)
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
            try:
                with open(baseline) as source:
                    baseline_xml = source.read()
            except Exception as fallback_exc:
                log('ERROR',
                    f'baseline fallback failed ({type(fallback_exc).__name__}: '
                    f'{fallback_exc}); nothing safe to serve')
                return 1

            # Validate with the same parser the app uses, same as the fetched-document
            # path -- "acceptance here guarantees acceptance there" has to hold on the
            # fallback branch too, or the operator only finds out the pasted baseline
            # was bad during the outage that forced this fallback in the first place.
            # Still write it: a bad baseline is not worse than no file at all, and
            # stopping the pod here would contradict the approved fail-open design.
            try:
                validate(baseline_xml, entity_id)
            except Exception as validate_exc:
                log('ERROR',
                    f'baseline at {baseline} failed validation '
                    f'({type(validate_exc).__name__}: {validate_exc}); writing it anyway '
                    f'because a bad baseline still beats no file -- fix the pasted '
                    f'idpMetadata value')

            try:
                write_atomic(output, baseline_xml)
            except Exception as fallback_exc:
                log('ERROR',
                    f'baseline fallback failed ({type(fallback_exc).__name__}: '
                    f'{fallback_exc}); nothing safe to serve')
                return 1
            return 0
        log('ERROR', 'fetch failed and no baseline is available; nothing safe to serve')
        return 1

    write_atomic(output, xml)
    log('INFO', f'IdP metadata fetched from {url}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

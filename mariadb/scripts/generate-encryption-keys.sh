#!/usr/bin/env bash
# Generates (or rotates) the TDE key material for this chart's `file_key_management`
# encryption plugin.
#
# Usage:
#   ./generate-encryption-keys.sh
#       Generate a fresh key pair (key_id 1). Use for a brand-new release.
#
#   ./generate-encryption-keys.sh --rotate <existing-keyfile.enc> <existing-keyfile.key>
#       Append a new key_id to an existing manifest, keeping every previous
#       key_id intact. Use this for rotation, so that
#       backups taken under the old key_id stay restorable. The file key
#       (the manifest's own encryption password) is also regenerated.
#       <existing-keyfile.enc> accepts either form — the raw binary keyfile.enc
#       or the base64 keyfile_b64 you'd pull straight out of Vault.
#
#   Add --keep-manifest to either form to also write the plaintext keyfile.txt
#   to OUT_DIR for inspection

# Output: keyfile.enc, keyfile.enc.b64, and keyfile.key,
# written to the current directory (override with OUT_DIR=/some/path).
#
# Write into Vault at mariadb-operator/encryption/<release fullname>:
#   - keyfile_b64: contents of keyfile.enc.b64
#   - filekey:     contents of keyfile.key

set -euo pipefail

usage() {
	echo "Usage:"
	echo "  $0 [--keep-manifest]                                                  # fresh key pair (key_id 1)"
	echo "  $0 --rotate <existing-keyfile.enc> <existing-keyfile.key> [--keep-manifest]  # add a new key_id"
	exit 1
}

# True if the file is entirely base64 characters — i.e. what you get pulling
# keyfile_b64 straight out of Vault, as opposed to the raw binary keyfile.enc.
# --rotate accepts either transparently.
is_base64() {
	[[ -s "$1" ]] || return 1
	[[ -z "$(tr -d 'A-Za-z0-9+/=\n\r \t' <"$1")" ]]
}

cleanup_paths=()
cleanup() {
	local f
	for f in "${cleanup_paths[@]+"${cleanup_paths[@]}"}"; do
		shred -u "$f" 2>/dev/null || rm -f "$f"
	done
}
trap cleanup EXIT

OUT_DIR="${OUT_DIR:-.}"

keep_manifest=false
args=()
for arg in "$@"; do
	if [[ "$arg" == "--keep-manifest" ]]; then
		keep_manifest=true
	else
		args+=("$arg")
	fi
done
set -- "${args[@]+"${args[@]}"}"

if [[ "$keep_manifest" == true ]]; then
	MANIFEST="$OUT_DIR/keyfile.txt"
else
	MANIFEST="$(mktemp)"
	cleanup_paths+=("$MANIFEST")
fi

rotated=false

if [[ $# -eq 0 ]]; then
	echo "1;$(openssl rand -hex 32)" >"$MANIFEST"
	openssl rand -hex 128 >"$OUT_DIR/keyfile.key"
	echo "Generated a fresh file key and a new manifest with key_id 1."

elif [[ "$1" == "--rotate" && $# -eq 3 ]]; then
	existing_enc="$2"
	existing_key="$3"
	[[ -f "$existing_enc" ]] || {
		echo "error: $existing_enc not found" >&2
		exit 1
	}
	[[ -f "$existing_key" ]] || {
		echo "error: $existing_key not found" >&2
		exit 1
	}

	if is_base64 "$existing_enc"; then
		decoded_enc="$(mktemp)"
		cleanup_paths+=("$decoded_enc")
		openssl base64 -d -in "$existing_enc" -out "$decoded_enc"
		existing_enc="$decoded_enc"
	fi

	openssl enc -d -aes-256-cbc -md sha1 -pass "file:$existing_key" -in "$existing_enc" -out "$MANIFEST"

	next_id=$(($(cut -d';' -f1 "$MANIFEST" | sort -n | tail -1) + 1))
	echo "$next_id;$(openssl rand -hex 32)" >>"$MANIFEST"
	openssl rand -hex 128 >"$OUT_DIR/keyfile.key"
	echo "Appended key_id $next_id to the existing manifest; earlier key_ids are still present."
	echo "Generated a fresh file key"
	rotated=true

else
	usage
fi

openssl enc -aes-256-cbc -md sha1 -pass "file:$OUT_DIR/keyfile.key" -in "$MANIFEST" -out "$OUT_DIR/keyfile.enc"
openssl base64 -in "$OUT_DIR/keyfile.enc" -out "$OUT_DIR/keyfile.enc.b64"
chmod 600 "$OUT_DIR/keyfile.key" "$OUT_DIR/keyfile.enc" "$OUT_DIR/keyfile.enc.b64"
if [[ "$keep_manifest" == true ]]; then
	chmod 600 "$MANIFEST"
fi

echo
echo "Wrote $OUT_DIR/keyfile.enc, $OUT_DIR/keyfile.enc.b64, and $OUT_DIR/keyfile.key"
if [[ "$keep_manifest" == true ]]; then
	echo "Also wrote $MANIFEST (plaintext manifest) — discard it once you're done inspecting it."
fi
echo
echo "Write into Vault at mariadb-operator/encryption/<release fullname>:"
echo "  keyfile_b64: contents of $OUT_DIR/keyfile.enc.b64"
echo "  filekey:     contents of $OUT_DIR/keyfile.key"

if [[ "$rotated" == true ]]; then
	echo
	echo "After pushing to Vault, set encryption.keyId: $next_id and roll the release"
fi

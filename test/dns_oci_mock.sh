#!/usr/bin/env sh
# shellcheck disable=SC2034

CASE="${1:-${CASE:-}}"
_DNS_OCI_MOCK_DIR="${TMPDIR:-/tmp}/dns_oci_mock.$$"

_fail() {
  printf '%s\n' "not ok - $*" >&2
  return 1
}

_assert_eq() {
  _expected="$1"
  _actual="$2"
  _message="${3:-values differ}"

  if [ "$_expected" != "$_actual" ]; then
    _fail "$_message: expected [$_expected], got [$_actual]"
    return 1
  fi
}

_assert_contains() {
  _haystack="$1"
  _needle="$2"
  _message="${3:-missing expected text}"

  case "$_haystack" in
  *"$_needle"*) return 0 ;;
  esac

  _fail "$_message: expected to contain [$_needle]"
}

_assert_not_contains() {
  _haystack="$1"
  _needle="$2"
  _message="${3:-unexpected text present}"

  case "$_haystack" in
  *"$_needle"*)
    _fail "$_message: did not expect [$_needle]"
    return 1
    ;;
  esac
}

_assert_success() {
  _message="$1"
  shift

  if "$@"; then
    return 0
  fi

  _fail "$_message"
}

_assert_failure() {
  _message="$1"
  shift

  if "$@"; then
    _fail "$_message"
    return 1
  fi

  return 0
}

_assert_function_exists() {
  _name="$1"

  if command -v "$_name" >/dev/null 2>&1; then
    return 0
  fi

  _fail "missing shell function: $_name"
}

_dns_oci_mock_append() {
  _file="$1"
  shift

  mkdir -p "$_DNS_OCI_MOCK_DIR"
  printf '%s\n' "$*" >>"$_DNS_OCI_MOCK_DIR/$_file"
}

_dns_oci_mock_read() {
  _file="$1"

  if [ -f "$_DNS_OCI_MOCK_DIR/$_file" ]; then
    cat "$_DNS_OCI_MOCK_DIR/$_file"
  fi
}

_dns_oci_mock_refresh_captures() {
  MOCK_SIGNED_REQUESTS="$(_dns_oci_mock_read signed_requests)"
  MOCK_SAVED_KEYS="$(_dns_oci_mock_read saved_keys)"
  MOCK_CLEARED_KEYS="$(_dns_oci_mock_read cleared_keys)"
  MOCK_READINI_KEYS="$(_dns_oci_mock_read readini_keys)"
  MOCK_DEBUG_LOG="$(_dns_oci_mock_read debug_log)"
  MOCK_SECURE_DEBUG_LOG="$(_dns_oci_mock_read secure_debug_log)"
  MOCK_ERROR_LOG="$(_dns_oci_mock_read error_log)"
  MOCK_INFO_LOG="$(_dns_oci_mock_read info_log)"
}

_reset_oci_mocks() {
  rm -rf "$_DNS_OCI_MOCK_DIR"
  mkdir -p "$_DNS_OCI_MOCK_DIR"

  MOCK_OCI_ZONES=""
  MOCK_SIGNED_REQUESTS=""
  MOCK_SAVED_KEYS=""
  MOCK_CLEARED_KEYS=""
  MOCK_READINI_KEYS=""
  MOCK_DEBUG_LOG=""
  MOCK_SECURE_DEBUG_LOG=""
  MOCK_ERROR_LOG=""
  MOCK_INFO_LOG=""

  OCI_CLI_TENANCY="ocid1.tenancy.oc1..test"
  OCI_CLI_USER="ocid1.user.oc1..test"
  OCI_CLI_REGION="us-ashburn-1"
  OCI_CLI_KEY="-----BEGIN PRIVATE KEY-----
TEST_DUMMY_PRIVATE_KEY
-----END PRIVATE KEY-----"
  OCI_CLI_CONFIG_FILE=""
  OCI_CLI_PROFILE=""
  OCI_CLI_KEY_FILE=""

  unset OCI_RESOURCE_PRINCIPAL_VERSION
  unset OCI_RESOURCE_PRINCIPAL_RPST
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM
  unset OCI_RESOURCE_PRINCIPAL_REGION
}

_signed_request() {
  _mock_method="$1"
  _mock_target="$2"
  _mock_body="$3"
  _mock_return_field="$4"

  _dns_oci_mock_append signed_requests "$_mock_method|$_mock_target|$_mock_body|$_mock_return_field"

  case "$_mock_method|$_mock_target|$_mock_return_field" in
  GET\|/20180115/zones/*\|id)
    _mock_zone="${_mock_target#/20180115/zones/}"
    for _candidate_zone in $MOCK_OCI_ZONES; do
      if [ "$_candidate_zone" = "$_mock_zone" ]; then
        printf '%s' "ocid1.dns-zone.oc1..$_mock_zone"
        return 0
      fi
    done
    return 0
    ;;
  PATCH\|/20180115/zones/*/records\|)
    printf '%s' "{}"
    return 0
    ;;
  esac

  return 0
}

_readaccountconf_mutable() {
  :
}

_saveaccountconf_mutable() {
  _dns_oci_mock_append saved_keys "$1=$2"
}

_clearaccountconf_mutable() {
  _dns_oci_mock_append cleared_keys "$1"
}

_readini() {
  _dns_oci_mock_append readini_keys "$1|$2|$3"
}

_debug() {
  _dns_oci_mock_append debug_log "$*"
}

_debug2() {
  _dns_oci_mock_append debug_log "$*"
}

_debug3() {
  _dns_oci_mock_append debug_log "$*"
}

_secure_debug() {
  _dns_oci_mock_append secure_debug_log "$*"
}

_secure_debug2() {
  _dns_oci_mock_append secure_debug_log "$*"
}

_secure_debug3() {
  _dns_oci_mock_append secure_debug_log "$*"
}

_err() {
  _dns_oci_mock_append error_log "$*"
}

_info() {
  _dns_oci_mock_append info_log "$*"
}

_load_oci_hook_under_test() {
  _dns_oci_saved_arg1="${1-}"
  _dns_oci_had_arg1="${1+x}"

  __dns_oci_test_noop() { :; }

  set -- __dns_oci_test_noop
  # shellcheck disable=SC1091
  . ./acme.sh

  if [ "$_dns_oci_had_arg1" ]; then
    set -- "$_dns_oci_saved_arg1"
  else
    set --
  fi

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh
}

le_test_oci_harness_bootstrap() {
  _reset_oci_mocks

  _assert_function_exists dns_oci_add &&
    _assert_function_exists dns_oci_rm &&
    _assert_function_exists _get_oci_zone &&
    _assert_function_exists _oci_config &&
    _assert_function_exists _get_zone || return 1

  _dns_oci_mock_refresh_captures
  _assert_eq "" "$MOCK_SIGNED_REQUESTS" "bootstrap must not call _signed_request"
}

_case_selected() {
  _case_name="$1"

  if [ -z "$CASE" ]; then
    return 0
  fi

  _old_ifs="$IFS"
  IFS=,
  for _selected_case in $CASE; do
    IFS="$_old_ifs"
    if [ "$_selected_case" = "$_case_name" ]; then
      return 0
    fi
    IFS=,
  done
  IFS="$_old_ifs"

  return 1
}

_run_cases() {
  _failures=0
  _selected=0
  _case_list="$_DNS_OCI_MOCK_DIR/cases"

  mkdir -p "$_DNS_OCI_MOCK_DIR"
  sed -n 's/^\(le_test_[A-Za-z0-9_]*\)().*/\1/p' "$0" | sort >"$_case_list"
  while IFS= read -r _case; do
    if _case_selected "$_case"; then
      _selected=$(_math "$_selected" + 1)
      if "$_case"; then
        printf '%s\n' "ok - $_case"
      else
        _failures=$(_math "$_failures" + 1)
      fi
    fi
  done <"$_case_list"

  if [ "$_selected" = "0" ]; then
    _fail "no selected cases matched: ${CASE:-<all>}"
    return 1
  fi

  [ "$_failures" = "0" ]
}

_load_oci_hook_under_test "$@"
_run_cases

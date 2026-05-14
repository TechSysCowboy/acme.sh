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
  MOCK_LOOKUP_LOG="$(_dns_oci_mock_read lookup_log)"
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
  MOCK_LOOKUP_LOG=""
  MOCK_OCI_PATCH_RESPONSE="{}"

  HOME="$_DNS_OCI_MOCK_DIR/home"
  mkdir -p "$HOME"

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

_mock_oci_zone_response() {
  _mock_zone="$1"
  _mock_status="$2"
  _mock_code="$3"
  _mock_id="$4"
  _mock_message="${5:-}"

  _dns_oci_mock_append zone_responses "$_mock_zone|$_mock_status|$_mock_code|$_mock_id|$_mock_message"
}

_mock_oci_zone_json() {
  _mock_status="$1"
  _mock_code="$2"
  _mock_id="$3"
  _mock_message="$4"
  _mock_sep=""

  printf '{'
  if [ "$_mock_status" ]; then
    printf '%s"status":%s' "$_mock_sep" "$_mock_status"
    _mock_sep=","
  fi
  if [ "$_mock_code" ]; then
    printf '%s"code":"%s"' "$_mock_sep" "$_mock_code"
    _mock_sep=","
  fi
  if [ "$_mock_id" ]; then
    printf '%s"id":"%s"' "$_mock_sep" "$_mock_id"
    _mock_sep=","
  fi
  if [ "$_mock_message" ]; then
    printf '%s"message":"%s"' "$_mock_sep" "$_mock_message"
  fi
  printf '}'
}

_install_oci_mock_stubs() {
  _signed_request() {
    _mock_method="$1"
    _mock_target="$2"
    _mock_body="$3"
    _mock_return_field="$4"

    _dns_oci_mock_append signed_requests "$_mock_method|$_mock_target|$_mock_body|$_mock_return_field"

    case "$_mock_method|$_mock_target" in
    GET\|/20180115/zones/*)
      _mock_zone="${_mock_target#/20180115/zones/}"

      if [ -f "$_DNS_OCI_MOCK_DIR/zone_responses" ]; then
        while IFS='|' read -r _candidate_zone _candidate_status _candidate_code _candidate_id _candidate_message; do
          if [ "$_candidate_zone" = "$_mock_zone" ]; then
            _dns_oci_mock_append lookup_log "$_candidate_zone|$_candidate_status|$_candidate_code|$_candidate_id"
            if [ "$_mock_return_field" = "id" ]; then
              printf '%s' "$_candidate_id"
            else
              _mock_oci_zone_json "$_candidate_status" "$_candidate_code" "$_candidate_id" "$_candidate_message"
            fi
            return 0
          fi
        done <"$_DNS_OCI_MOCK_DIR/zone_responses"
      fi

      for _candidate_zone in $MOCK_OCI_ZONES; do
        if [ "$_candidate_zone" = "$_mock_zone" ]; then
          _candidate_id="ocid1.dns-zone.oc1..$_mock_zone"
          _dns_oci_mock_append lookup_log "$_mock_zone|200||$_candidate_id"
          if [ "$_mock_return_field" = "id" ]; then
            printf '%s' "$_candidate_id"
          else
            _mock_oci_zone_json "200" "" "$_candidate_id" ""
          fi
          return 0
        fi
      done

      _dns_oci_mock_append lookup_log "$_mock_zone|404|NotAuthorizedOrNotFound|"
      if [ -z "$_mock_return_field" ]; then
        _mock_oci_zone_json "404" "NotAuthorizedOrNotFound" "" ""
      fi
      return 0
      ;;
    esac

    case "$_mock_method|$_mock_target|$_mock_return_field" in
    PATCH\|/20180115/zones/*/records\|)
      printf '%s' "$MOCK_OCI_PATCH_RESPONSE"
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
  _install_oci_mock_stubs
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

le_test_oci_parent_zone_add() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "parent-zone add should succeed" \
    dns_oci_add "_acme-challenge.www.example.com" "parent-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/example.com||" "parent zone lookup missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "parent zone PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.www.example.com"' "parent record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rtype":"TXT"' "TXT rtype missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"parent-value"' "parent TXT value missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "ADD operation missing"
}

le_test_oci_delegated_zone_add() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="dev.example.com example.com"

  _assert_success "delegated-zone add should succeed" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "delegated-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/dev.example.com||" "delegated zone lookup missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/dev.example.com/records|" "delegated PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.www.dev.example.com"' "delegated record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"delegated-value"' "delegated TXT value missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "delegated ADD operation missing"
}

le_test_oci_apex_wildcard_add() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "apex wildcard add should succeed" \
    dns_oci_add "_acme-challenge.example.com" "apex-wildcard-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "apex wildcard PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.example.com"' "apex wildcard record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rtype":"TXT"' "apex wildcard TXT rtype missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "apex wildcard ADD operation missing"
}

le_test_oci_delegated_wildcard_add() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="dev.example.com example.com"

  _assert_success "delegated wildcard add should succeed" \
    dns_oci_add "_acme-challenge.dev.example.com" "delegated-wildcard-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/dev.example.com/records|" "delegated wildcard PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.dev.example.com"' "delegated wildcard record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rtype":"TXT"' "delegated wildcard TXT rtype missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "delegated wildcard ADD operation missing"
}

le_test_oci_parent_fallback() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "parent fallback add should succeed" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "fallback-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/dev.example.com||" "delegated lookup attempt missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/example.com||" "parent fallback lookup missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "parent fallback PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.www.dev.example.com"' "fallback record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"fallback-value"' "fallback TXT value missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "fallback ADD operation missing"
}

le_test_oci_lookup_ambiguous_404_falls_back() {
  _reset_oci_mocks
  _mock_oci_zone_response "dev.example.com" "404" "NotAuthorizedOrNotFound" "" "ambiguous lookup miss"
  MOCK_OCI_ZONES="example.com"

  _assert_success "ambiguous 404 lookup should fall back to parent" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "ambiguous-fallback-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_LOOKUP_LOG" "dev.example.com|404|NotAuthorizedOrNotFound|" "ambiguous delegated lookup signal missing" &&
    _assert_contains "$MOCK_DEBUG_LOG" "dev.example.com status=404" "ambiguous lookup debug status missing" &&
    _assert_contains "$MOCK_DEBUG_LOG" "trying example.com" "ambiguous lookup debug fallback missing" &&
    _assert_contains "$MOCK_DEBUG_LOG" "_domain example.com" "selected parent zone debug missing" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "Authorization:" "normal debug leaked Authorization header" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "TEST_DUMMY_PRIVATE_KEY" "normal debug leaked private key" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "TEST_DUMMY_RPST" "normal debug leaked RPST" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "ambiguous fallback PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"ambiguous-fallback-value"' "ambiguous fallback TXT value missing"
}

le_test_oci_lookup_visible_authz_fails_hard() {
  _reset_oci_mocks
  _mock_oci_zone_response "dev.example.com" "403" "NotAuthorized" "" "caller lacks zone read permission"
  MOCK_OCI_ZONES="example.com"

  _assert_failure "visible authz lookup should fail hard" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "authz-failure-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_LOOKUP_LOG" "dev.example.com|403|NotAuthorized|" "authz delegated lookup signal missing" &&
    _assert_contains "$MOCK_ERROR_LOG" "authorization or permission failure" "authz hard-fail error missing" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "Authorization:" "normal debug leaked Authorization header" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/example.com||" "visible authz must not fall through to parent" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "visible authz failure must not PATCH"
}

le_test_oci_no_zone_failure() {
  _reset_oci_mocks
  MOCK_OCI_ZONES=""

  _assert_failure "no-zone add should fail" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "missing-zone-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "Error: DNS Zone not found" "no-zone error missing" &&
    _assert_contains "$MOCK_ERROR_LOG" "Check that the zone exists and the user has permission to read it." "no-zone hint missing" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "no-zone failure must not PATCH"
}

le_test_oci_patch_failure_hints() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  MOCK_OCI_PATCH_RESPONSE=""

  _assert_failure "PATCH add failure should fail" \
    dns_oci_add "_acme-challenge.www.example.com" "patch-failure-value" &&
    _assert_failure "PATCH remove failure should fail" \
      dns_oci_rm "_acme-challenge.www.example.com" "patch-failure-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "Check that the user has permission to add records to this zone." "ADD PATCH failure hint missing" &&
    _assert_contains "$MOCK_ERROR_LOG" "Check that the user has permission to remove records from this zone." "REMOVE PATCH failure hint missing"
}

le_test_oci_add_remove_symmetry() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "symmetry add should succeed" \
    dns_oci_add "_acme-challenge.www.example.com" "symmetric-value" &&
    _assert_success "symmetry remove should succeed" \
      dns_oci_rm "_acme-challenge.www.example.com" "symmetric-value" || return 1

  _dns_oci_mock_refresh_captures
  _remove_request=$(printf "%s\n" "$MOCK_SIGNED_REQUESTS" | grep '"operation":"REMOVE"')
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "symmetry PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.www.example.com"' "symmetry record domain missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"symmetric-value"' "symmetry TXT value missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"ttl": 30' "ADD payload TTL missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "symmetry ADD operation missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"REMOVE"' "symmetry REMOVE operation missing" &&
    _assert_not_contains "$_remove_request" '"ttl":' "REMOVE payload must not include TTL" &&
    _assert_contains "$MOCK_INFO_LOG" "Success: added TXT record for _acme-challenge.www.example.com." "ADD success text changed" &&
    _assert_contains "$MOCK_INFO_LOG" "Success: removed TXT record for _acme-challenge.www.example.com." "REMOVE success text changed"
}

le_test_oci_txt_value_json_escape() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "TXT value JSON escaping should succeed" \
    dns_oci_add "_acme-challenge.www.example.com" 'token "quoted" backslash \ value' || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"token \"quoted\" backslash \\ value"' "TXT value JSON escaping missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "TXT escape ADD operation missing"
}

le_test_oci_record_domain_json_escape() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "record domain JSON escaping should preserve realistic hook input" \
    dns_oci_add "_acme-challenge.www-01.example.com" "domain-escape-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" '"domain":"_acme-challenge.www-01.example.com"' "record domain JSON text missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"domain-escape-value"' "record domain test TXT value missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"ADD"' "record domain escape ADD operation missing"
}

le_test_oci_signed_request_return_field() {
  _reset_oci_mocks

  # Restore the real function for this narrow parser fixture, then stub only
  # the lower HTTP/signing boundary helpers it depends on.
  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "REAL_GET|$1"
    printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}'
  }

  _fingerprint() {
    printf '%s' "00:11:22:33"
  }

  _sign() {
    cat >/dev/null
    printf '%s' "signed"
  }

  _mktemp() {
    _mock_tmp="$_DNS_OCI_MOCK_DIR/signing-key"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  _actual=$(_signed_request "GET" "/20180115/zones/example.com" "" "id")
  _install_oci_mock_stubs

  _assert_eq "ocid1.dns-zone.oc1..example" "$_actual" "return-field parser should not append stray characters"
}

le_test_oci_auth_api_key() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "API-key auth should reach mocked PATCH" \
    dns_oci_add "_acme-challenge.www.example.com" "api-key-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "API-key auth did not reach PATCH" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_TENANCY=ocid1.tenancy.oc1..test" "tenancy was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_USER=ocid1.user.oc1..test" "user was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_REGION=us-ashburn-1" "region was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_KEY=-----BEGIN PRIVATE KEY-----" "key was not persisted" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL" "resource principal values must not be persisted by API-key auth" &&
    _assert_eq "" "$MOCK_READINI_KEYS" "API-key env path should not read real OCI config"
}

le_test_oci_auth_missing() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  OCI_CLI_KEY=""
  OCI_CLI_KEY_FILE=""
  unset OCI_RESOURCE_PRINCIPAL_VERSION
  unset OCI_RESOURCE_PRINCIPAL_RPST
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM
  unset OCI_RESOURCE_PRINCIPAL_REGION

  _assert_failure "missing key material should fail before PATCH" \
    dns_oci_add "_acme-challenge.www.example.com" "missing-auth-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "unable to find key file path" "missing key-file error absent" &&
    _assert_contains "$MOCK_ERROR_LOG" "unable to load private API signing key" "missing key-material error absent" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "missing auth must not PATCH"
}

le_test_oci_auth_resource_principal_current_state() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="/tmp/nonexistent-rpst"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="/tmp/nonexistent-private.pem"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  # Phase 3/4 must change this fixture from current-failure characterization
  # to fallback-success proof when resource principal auth is implemented.
  _assert_failure "resource-principal-only auth should fail before Phase 3/4 fallback" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-current-state-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "unable to read OCI_CLI_TENANCY" "current-state missing tenancy error absent" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "resource-principal current state must not PATCH" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_RPST" "RPST path must not be saved" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM" "resource principal private key path must not be saved"
}

le_test_oci_secure_debug_boundaries() {
  _reset_oci_mocks
  _dummy_auth_header="Authorization: Signature ST\$TEST_DUMMY_RPST"

  _debug "normal" "ordinary diagnostic"
  _secure_debug "private-key" "TEST_DUMMY_PRIVATE_KEY"
  _secure_debug2 "rpst" "TEST_DUMMY_RPST"
  _secure_debug3 "authorization" "$_dummy_auth_header"

  _dns_oci_mock_refresh_captures
  _assert_not_contains "$MOCK_DEBUG_LOG" "TEST_DUMMY_PRIVATE_KEY" "normal debug leaked private key" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "TEST_DUMMY_RPST" "normal debug leaked RPST" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "Authorization:" "normal debug leaked Authorization header" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" 'ST$' "normal debug leaked ST token marker" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" "TEST_DUMMY_PRIVATE_KEY" "secure debug did not capture private key fixture" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" "TEST_DUMMY_RPST" "secure debug did not capture RPST fixture" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" "Authorization:" "secure debug did not capture Authorization fixture" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" 'ST$' "secure debug did not capture ST token marker"
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

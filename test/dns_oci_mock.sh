#!/usr/bin/env sh
# shellcheck disable=SC2034,SC2329

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
  MOCK_OCI_READINI_TENANCY=""
  MOCK_OCI_READINI_USER=""
  MOCK_OCI_READINI_REGION=""
  MOCK_OCI_READINI_KEY_FILE=""
  unset _H1
  unset _H2
  unset _H3
  unset _H4
  unset _H5

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
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE
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

_mock_account_conf() {
  _dns_oci_mock_append account_conf "$1=$2"
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

    if [ "$_oci_auth_mode" = "resource_principal" ]; then
      _err "Error: _oci_auth_mode=resource_principal; resource principal signing failed."
      return 1
    fi

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
    _mock_account_key="$1"
    _mock_account_value=""

    if [ -f "$_DNS_OCI_MOCK_DIR/account_conf" ]; then
      while IFS='=' read -r _candidate_key _candidate_value; do
        if [ "$_candidate_key" = "$_mock_account_key" ]; then
          _mock_account_value="$_candidate_value"
        fi
      done <"$_DNS_OCI_MOCK_DIR/account_conf"
    fi

    printf '%s' "$_mock_account_value"
  }

  _saveaccountconf_mutable() {
    _dns_oci_mock_append saved_keys "$1=$2"
  }

  _clearaccountconf_mutable() {
    _dns_oci_mock_append cleared_keys "$1"
  }

  _readini() {
    _mock_ini_section="${3:-DEFAULT}"
    _dns_oci_mock_append readini_keys "$1|$2|$_mock_ini_section"

    case "$2" in
    tenancy)
      printf '%s' "$MOCK_OCI_READINI_TENANCY"
      ;;
    user)
      printf '%s' "$MOCK_OCI_READINI_USER"
      ;;
    region)
      printf '%s' "$MOCK_OCI_READINI_REGION"
      ;;
    key_file)
      printf '%s' "$MOCK_OCI_READINI_KEY_FILE"
      ;;
    esac
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

le_test_oci_lookup_404_auth_message_falls_back() {
  _reset_oci_mocks
  _mock_oci_zone_response "_acme-challenge.test.example.com" "404" "NotAuthorizedOrNotFound" "" "NotAuthorizedOrNotFound: Authorization failed or requested resource not found."
  MOCK_OCI_ZONES="example.com"

  _assert_success "live-shaped OCI 404 auth/not-found lookup should fall back to parent" \
    dns_oci_add "_acme-challenge.test.example.com" "live-shaped-fallback-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_LOOKUP_LOG" "_acme-challenge.test.example.com|404|NotAuthorizedOrNotFound|" "live-shaped 404 lookup signal missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/test.example.com||" "live-shaped 404 must continue to next candidate" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "GET|/20180115/zones/example.com||" "live-shaped 404 must reach parent zone" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "live-shaped fallback PATCH target missing" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"rdata":"live-shaped-fallback-value"' "live-shaped fallback TXT value missing" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "authorization or permission failure" "live-shaped 404 must not be reported as hard authz"
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

le_test_oci_provider_metadata_documents_current_behavior() {
  _reset_oci_mocks

  _assert_contains "$dns_oci_info" "API-key" "metadata must document API-key auth" &&
    _assert_contains "$dns_oci_info" "resource principal" "metadata must document resource principal auth" &&
    _assert_contains "$dns_oci_info" "fallback" "metadata must document resource principal fallback" &&
    _assert_contains "$dns_oci_info" "delegated" "metadata must document delegated zone behavior" &&
    _assert_contains "$dns_oci_info" "subzone" "metadata must document subzone behavior" &&
    _assert_contains "$dns_oci_info" "OCI_RESOURCE_PRINCIPAL_VERSION" "metadata must list RP version env" &&
    _assert_contains "$dns_oci_info" "OCI_RESOURCE_PRINCIPAL_RPST" "metadata must list RPST env" &&
    _assert_contains "$dns_oci_info" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM" "metadata must list private PEM env" &&
    _assert_contains "$dns_oci_info" "OCI_RESOURCE_PRINCIPAL_REGION" "metadata must list RP region env" &&
    _assert_contains "$dns_oci_info" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE" "metadata must list optional passphrase env" || return 1

  _hook_text=$(cat dnsapi/dns_oci.sh)
  _test_text=$(cat test/dns_oci_mock.sh)
  _stale_passphrase_phrase="passphrase is not"
  _stale_passphrase_phrase="$_stale_passphrase_phrase supported"
  _stale_signing_phrase="signing is not"
  _stale_signing_phrase="$_stale_signing_phrase implemented"
  _assert_not_contains "$_hook_text$_test_text" "$_stale_passphrase_phrase" "stale passphrase unsupported prose remains" &&
    _assert_not_contains "$_hook_text$_test_text" "$_stale_signing_phrase" "stale resource-principal signing prose remains"
}

le_test_oci_rp_loads_inline_material() {
  _reset_oci_mocks
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_INLINE_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_INLINE_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="TEST_INLINE_PASSPHRASE"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "inline resource principal material should load" \
    _oci_load_resource_principal_material || return 1

  _dns_oci_mock_refresh_captures
  _assert_eq "TEST_INLINE_RPST" "$_oci_rp_rpst" "inline RPST was not loaded" &&
    _assert_eq "TEST_INLINE_PRIVATE_PEM" "$_oci_rp_private_pem" "inline private PEM was not loaded" &&
    _assert_eq "TEST_INLINE_PASSPHRASE" "$_oci_rp_private_pem_passphrase" "inline passphrase was not loaded" &&
    _assert_eq "us-ashburn-1" "$_oci_rp_region" "inline region was not loaded" &&
    _assert_eq "us-ashburn-1" "$OCI_RESOURCE_PRINCIPAL_REGION" "resource principal region env changed" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource principal values must not be saved" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource principal values must not be cleared" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_INLINE_RPST" "normal logs leaked inline RPST" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_INLINE_PRIVATE_PEM" "normal logs leaked inline private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_INLINE_PASSPHRASE" "normal logs leaked inline passphrase" || return 1

  _oci_reset_resource_principal_material
  _assert_eq "" "$_oci_rp_rpst" "reset should blank inline RPST" &&
    _assert_eq "" "$_oci_rp_private_pem" "reset should blank inline private PEM" &&
    _assert_eq "" "$_oci_rp_private_pem_passphrase" "reset should blank inline passphrase"
}

le_test_oci_rp_loads_path_material() {
  _reset_oci_mocks
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  _mock_rpst_file="$_DNS_OCI_MOCK_DIR/rpst.token"
  _mock_private_pem_file="$_DNS_OCI_MOCK_DIR/private.pem"
  _mock_passphrase_file="$_DNS_OCI_MOCK_DIR/passphrase.txt"
  printf '%s' "TEST_PATH_RPST" >"$_mock_rpst_file"
  printf '%s' "TEST_PATH_PRIVATE_PEM" >"$_mock_private_pem_file"
  printf '%s' "TEST_PATH_PASSPHRASE" >"$_mock_passphrase_file"
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="$_mock_rpst_file"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="$_mock_private_pem_file"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="$_mock_passphrase_file"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "path resource principal material should load" \
    _oci_load_resource_principal_material || return 1

  _dns_oci_mock_refresh_captures
  _assert_eq "TEST_PATH_RPST" "$_oci_rp_rpst" "path RPST was not loaded" &&
    _assert_eq "TEST_PATH_PRIVATE_PEM" "$_oci_rp_private_pem" "path private PEM was not loaded" &&
    _assert_eq "TEST_PATH_PASSPHRASE" "$_oci_rp_private_pem_passphrase" "path passphrase was not loaded" &&
    _assert_eq "us-ashburn-1" "$_oci_rp_region" "path region was not loaded" &&
    _assert_eq "us-ashburn-1" "$OCI_RESOURCE_PRINCIPAL_REGION" "resource principal region env changed" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource principal values must not be saved" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource principal values must not be cleared" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATH_RPST" "normal logs leaked path RPST" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATH_PRIVATE_PEM" "normal logs leaked path private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATH_PASSPHRASE" "normal logs leaked path passphrase" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "$_mock_rpst_file" "normal logs leaked RPST path" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "$_mock_private_pem_file" "normal logs leaked private PEM path" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "$_mock_passphrase_file" "normal logs leaked passphrase path" || return 1

  _oci_reset_resource_principal_material
  _assert_eq "" "$_oci_rp_rpst" "reset should blank path RPST" &&
    _assert_eq "" "$_oci_rp_private_pem" "reset should blank path private PEM" &&
    _assert_eq "" "$_oci_rp_private_pem_passphrase" "reset should blank path passphrase"
}

le_test_oci_rp_missing_material_reports_env_names() {
  _reset_oci_mocks
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_MISSING_RPST"
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="TEST_MISSING_PASSPHRASE"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "missing resource principal material should fail" \
    _oci_load_resource_principal_material || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM" "missing private PEM env name absent" &&
    _assert_contains "$MOCK_ERROR_LOG" "missing" "missing failure class absent" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "TEST_MISSING_RPST" "missing-material error leaked RPST" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "TEST_MISSING_PASSPHRASE" "missing-material error leaked passphrase" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "us-ashburn-1" "missing-material error leaked region value" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "missing-material path must not save RP values" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "missing-material path must not clear RP values" &&
    _assert_eq "" "$_oci_rp_rpst" "missing-material failure should reset RPST" &&
    _assert_eq "" "$_oci_rp_private_pem" "missing-material failure should reset private PEM" &&
    _assert_eq "" "$_oci_rp_private_pem_passphrase" "missing-material failure should reset passphrase"
}

le_test_oci_rp_unsupported_version_reports_env_name() {
  _reset_oci_mocks
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  _mock_rpst_file="$_DNS_OCI_MOCK_DIR/version-rpst.token"
  _mock_private_pem_file="$_DNS_OCI_MOCK_DIR/version-private.pem"
  _mock_passphrase_file="$_DNS_OCI_MOCK_DIR/version-passphrase.txt"
  printf '%s' "TEST_VERSION_RPST" >"$_mock_rpst_file"
  printf '%s' "TEST_VERSION_PRIVATE_PEM" >"$_mock_private_pem_file"
  printf '%s' "TEST_VERSION_PASSPHRASE" >"$_mock_passphrase_file"
  OCI_RESOURCE_PRINCIPAL_VERSION="3.0"
  OCI_RESOURCE_PRINCIPAL_RPST="$_mock_rpst_file"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="$_mock_private_pem_file"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="$_mock_passphrase_file"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "unsupported resource principal version should fail" \
    _oci_load_resource_principal_material || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "OCI_RESOURCE_PRINCIPAL_VERSION=2.2" "unsupported-version env contract absent" &&
    _assert_contains "$MOCK_ERROR_LOG" "unsupported" "unsupported-version failure class absent" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "3.0" "unsupported-version error leaked version value" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "TEST_VERSION_RPST" "unsupported-version error leaked RPST" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "TEST_VERSION_PRIVATE_PEM" "unsupported-version error leaked private PEM" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "TEST_VERSION_PASSPHRASE" "unsupported-version error leaked passphrase" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "$_mock_rpst_file" "unsupported-version error leaked RPST path" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "$_mock_private_pem_file" "unsupported-version error leaked private PEM path" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "$_mock_passphrase_file" "unsupported-version error leaked passphrase path" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "unsupported-version path must not save RP values" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "unsupported-version path must not clear RP values"
}

le_test_oci_rp_signs_get_with_st_key_id() {
  _reset_oci_mocks

  # Restore the real signer for exact header proof, then stub only the lower
  # HTTP and signing boundaries.
  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "REAL_GET|$1|$_H1|$_H2"
    printf '%s' '{}'
  }

  _sign() {
    _mock_key_file="$1"
    _mock_algorithm="$2"
    _dns_oci_mock_append signing_algorithms "$_mock_algorithm"
    cat >"$_DNS_OCI_MOCK_DIR/signing_string"
    cat "$_mock_key_file" >"$_DNS_OCI_MOCK_DIR/signing_key"
    printf '%s' "TEST_SIGNATURE"
  }

  _mktemp() {
    _mock_tmp="$_DNS_OCI_MOCK_DIR/rp-signing-key"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  _oci_auth_mode="resource_principal"
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_INLINE_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_INLINE_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  if ! _signed_request "GET" "/20180115/zones/example.com" "" >"$_DNS_OCI_MOCK_DIR/response"; then
    _fail "resource-principal GET should sign with ST keyId"
    return 1
  fi

  _dns_oci_mock_refresh_captures
  _mock_response="$(_dns_oci_mock_read response)"
  _mock_signing_string="$(_dns_oci_mock_read signing_string)"
  _mock_signing_key="$(_dns_oci_mock_read signing_key)"
  _install_oci_mock_stubs

  _assert_contains "$MOCK_SIGNED_REQUESTS" "REAL_GET|https://dns.us-ashburn-1.oraclecloud.com/20180115/zones/example.com|date:" "GET did not receive date header" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "Authorization: Signature" "GET did not receive Authorization header" &&
    _assert_contains "$_H2" "Authorization: Signature" "GET Authorization header missing Signature scheme" &&
    _assert_contains "$_H2" 'version="1"' "GET Authorization version missing" &&
    _assert_contains "$_H2" "keyId=\"ST\$TEST_INLINE_RPST\"" "GET Authorization keyId must use ST token shape" &&
    _assert_contains "$_H2" 'algorithm="rsa-sha256"' "GET Authorization algorithm missing" &&
    _assert_contains "$_H2" 'headers="(request-target) date host"' "GET signed header list changed" &&
    _assert_contains "$_H2" 'signature="TEST_SIGNATURE"' "GET signature missing" &&
    _assert_eq "{}" "$_mock_response" "GET response body changed" &&
    _assert_contains "$_mock_signing_string" "(request-target): get /20180115/zones/example.com" "GET signing string missing request target" &&
    _assert_contains "$_mock_signing_string" "date:" "GET signing string missing date" &&
    _assert_contains "$_mock_signing_string" "host: dns.us-ashburn-1.oraclecloud.com" "GET signing string missing RP host" &&
    _assert_eq "TEST_INLINE_PRIVATE_PEM" "$_mock_signing_key" "GET signer did not write RP private PEM to temp key" &&
    _assert_success "GET signer should remove temp key file" test ! -e "$_DNS_OCI_MOCK_DIR/rp-signing-key" &&
    _assert_eq "" "$_oci_rp_rpst" "GET signer should reset loaded RPST" &&
    _assert_eq "" "$_oci_rp_private_pem" "GET signer should reset loaded private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_INLINE_RPST" "normal logs leaked RPST" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_INLINE_PRIVATE_PEM" "normal logs leaked private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "ST\$TEST_INLINE_RPST" "normal logs leaked ST keyId" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "Authorization:" "normal logs leaked Authorization header" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_SIGNATURE" "normal logs leaked signature"
}

le_test_oci_rp_signs_patch_body_headers() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _post() {
    _mock_body="$1"
    _mock_url="$2"
    _mock_method="$4"
    _dns_oci_mock_append signed_requests "REAL_PATCH|$_mock_url|$_mock_method|$_H1|$_H2|$_H3|$_H4|$_H5|$_mock_body"
    printf '%s' '{"patched":true}'
  }

  _sign() {
    _mock_key_file="$1"
    _mock_algorithm="$2"
    _dns_oci_mock_append signing_algorithms "$_mock_algorithm"
    cat >"$_DNS_OCI_MOCK_DIR/patch_signing_string"
    cat "$_mock_key_file" >"$_DNS_OCI_MOCK_DIR/patch_signing_key"
    printf '%s' "TEST_PATCH_SIGNATURE"
  }

  _mktemp() {
    _mock_tmp="$_DNS_OCI_MOCK_DIR/rp-patch-signing-key"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  _oci_auth_mode="resource_principal"
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_PATCH_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_PATCH_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"
  _mock_body='{"items":[]}'
  _mock_body_length="${#_mock_body}"

  if ! _signed_request "PATCH" "/20180115/zones/example.com/records" "$_mock_body" >"$_DNS_OCI_MOCK_DIR/patch_response"; then
    _fail "resource-principal PATCH should sign body headers"
    return 1
  fi

  _dns_oci_mock_refresh_captures
  _mock_response="$(_dns_oci_mock_read patch_response)"
  _mock_signing_string="$(_dns_oci_mock_read patch_signing_string)"
  _mock_signing_key="$(_dns_oci_mock_read patch_signing_key)"
  _install_oci_mock_stubs

  _assert_contains "$MOCK_SIGNED_REQUESTS" "REAL_PATCH|https://dns.us-ashburn-1.oraclecloud.com/20180115/zones/example.com/records|PATCH|date:" "PATCH did not receive date header" &&
    _assert_contains "$_H2" "x-content-sha256:" "PATCH body hash header missing" &&
    _assert_eq "content-type: application/json" "$_H3" "PATCH content type header changed" &&
    _assert_eq "content-length: $_mock_body_length" "$_H4" "PATCH content length header changed" &&
    _assert_contains "$_H5" "Authorization: Signature" "PATCH Authorization header missing Signature scheme" &&
    _assert_contains "$_H5" "keyId=\"ST\$TEST_PATCH_RPST\"" "PATCH Authorization keyId must use ST token shape" &&
    _assert_contains "$_H5" 'headers="(request-target) date host x-content-sha256 content-type content-length"' "PATCH signed header list changed" &&
    _assert_contains "$_H5" 'signature="TEST_PATCH_SIGNATURE"' "PATCH signature missing" &&
    _assert_eq '{"patched":true}' "$_mock_response" "PATCH response body changed" &&
    _assert_contains "$_mock_signing_string" "(request-target): patch /20180115/zones/example.com/records" "PATCH signing string missing request target" &&
    _assert_contains "$_mock_signing_string" "x-content-sha256:" "PATCH signing string missing body hash" &&
    _assert_contains "$_mock_signing_string" "content-type: application/json" "PATCH signing string missing content type" &&
    _assert_contains "$_mock_signing_string" "content-length: $_mock_body_length" "PATCH signing string missing content length" &&
    _assert_eq "TEST_PATCH_PRIVATE_PEM" "$_mock_signing_key" "PATCH signer did not write RP private PEM to temp key" &&
    _assert_success "PATCH signer should remove temp key file" test ! -e "$_DNS_OCI_MOCK_DIR/rp-patch-signing-key" &&
    _assert_eq "" "$_oci_rp_rpst" "PATCH signer should reset loaded RPST" &&
    _assert_eq "" "$_oci_rp_private_pem" "PATCH signer should reset loaded private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATCH_RPST" "normal logs leaked PATCH RPST" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATCH_PRIVATE_PEM" "normal logs leaked PATCH private PEM" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "ST\$TEST_PATCH_RPST" "normal logs leaked PATCH ST keyId" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "Authorization:" "normal logs leaked PATCH Authorization header" &&
    _assert_not_contains "$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG" "TEST_PATCH_SIGNATURE" "normal logs leaked PATCH signature"
}

le_test_oci_rp_refreshes_path_material_between_requests() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _mock_rpst_file="$_DNS_OCI_MOCK_DIR/refresh-rpst.token"
  _mock_private_pem_file="$_DNS_OCI_MOCK_DIR/refresh-private.pem"
  printf '%s' "TEST_RPST_GET" >"$_mock_rpst_file"
  printf '%s' "TEST_PRIVATE_PEM_GET" >"$_mock_private_pem_file"

  _get() {
    _dns_oci_mock_append signed_requests "GET|$1|$_H2"
    printf '%s' "TEST_RPST_PATCH" >"$_mock_rpst_file"
    printf '%s' "TEST_PRIVATE_PEM_PATCH" >"$_mock_private_pem_file"
    printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}'
  }

  _post() {
    _dns_oci_mock_append signed_requests "PATCH|$2|$_H5|$1"
    printf '%s' '{}'
  }

  _sign() {
    _mock_key_file="$1"
    _mock_signing_string=$(cat)
    case "$_mock_signing_string" in
    *"(request-target): get "*) _mock_request="GET" ;;
    *) _mock_request="PATCH" ;;
    esac
    cat "$_mock_key_file" >"$_DNS_OCI_MOCK_DIR/refresh_key_$_mock_request"
    printf '%s' "TEST_${_mock_request}_SIGNATURE"
  }

  _mktemp() {
    _mock_tmp_counter=$(_math "${_mock_tmp_counter:-0}" + 1)
    _mock_tmp="$_DNS_OCI_MOCK_DIR/rp-refresh-signing-key-$_mock_tmp_counter"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="$_mock_rpst_file"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="$_mock_private_pem_file"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "resource-principal public add should refresh path-backed material" \
    dns_oci_add "example.com" "refresh-value" || return 1

  _dns_oci_mock_refresh_captures
  _mock_get_key="$(_dns_oci_mock_read refresh_key_GET)"
  _mock_patch_key="$(_dns_oci_mock_read refresh_key_PATCH)"
  _install_oci_mock_stubs

  _mock_get_count=$(printf '%s\n' "$MOCK_SIGNED_REQUESTS" | grep -c '^GET|')
  _mock_patch_count=$(printf '%s\n' "$MOCK_SIGNED_REQUESTS" | grep -c '^PATCH|')
  _assert_eq "1" "$_mock_get_count" "refresh test should perform one GET" &&
    _assert_eq "1" "$_mock_patch_count" "refresh test should perform one PATCH" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "keyId=\"ST\$TEST_RPST_GET\"" "GET did not use initial RPST" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "keyId=\"ST\$TEST_RPST_PATCH\"" "PATCH did not use refreshed RPST" &&
    _assert_eq "TEST_PRIVATE_PEM_GET" "$_mock_get_key" "GET did not use initial private PEM" &&
    _assert_eq "TEST_PRIVATE_PEM_PATCH" "$_mock_patch_key" "PATCH did not use refreshed private PEM" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource-principal names must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_RPST_GET" "initial RPST must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_RPST_PATCH" "refreshed RPST must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_PRIVATE_PEM_GET" "initial private PEM must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_PRIVATE_PEM_PATCH" "refreshed private PEM must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "$_mock_rpst_file" "RPST path must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "$_mock_private_pem_file" "private PEM path must not be saved or cleared"
}

le_test_oci_rp_does_not_persist_or_normal_log_material() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "GET|$1|$_H2"
    printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}'
  }

  _post() {
    _dns_oci_mock_append signed_requests "PATCH|$2|$_H5|$1"
    printf '%s' '{}'
  }

  _sign() {
    _mock_key_file="$1"
    _mock_signing_string=$(cat)
    case "$_mock_signing_string" in
    *"(request-target): get "*) _mock_request="GET" ;;
    *) _mock_request="PATCH" ;;
    esac
    cat "$_mock_key_file" >"$_DNS_OCI_MOCK_DIR/no_log_key_$_mock_request"
    printf '%s' "TEST_PUBLIC_${_mock_request}_SIGNATURE"
  }

  _mktemp() {
    _mock_tmp_counter=$(_math "${_mock_tmp_counter:-0}" + 1)
    _mock_tmp="$_DNS_OCI_MOCK_DIR/rp-public-signing-key-$_mock_tmp_counter"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_PUBLIC_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_PUBLIC_PRIVATE_PEM"
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "resource-principal public add should keep normal logs clean" \
    dns_oci_add "example.com" "no-log-value" || return 1

  _dns_oci_mock_refresh_captures
  _install_oci_mock_stubs
  _normal_logs="$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG"

  _assert_contains "$MOCK_SIGNED_REQUESTS" "keyId=\"ST\$TEST_PUBLIC_RPST\"" "public RP add did not use RPST keyId" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "RP names must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_PUBLIC_RPST" "RPST must not be saved or cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS$MOCK_CLEARED_KEYS" "TEST_PUBLIC_PRIVATE_PEM" "private PEM must not be saved or cleared" &&
    _assert_not_contains "$_normal_logs" "TEST_PUBLIC_RPST" "normal logs leaked RPST" &&
    _assert_not_contains "$_normal_logs" "TEST_PUBLIC_PRIVATE_PEM" "normal logs leaked private PEM" &&
    _assert_not_contains "$_normal_logs" "Authorization:" "normal logs leaked Authorization" &&
    _assert_not_contains "$_normal_logs" "ST\$" "normal logs leaked ST keyId" &&
    _assert_not_contains "$_normal_logs" "TEST_PUBLIC_GET_SIGNATURE" "normal logs leaked GET signature" &&
    _assert_not_contains "$_normal_logs" "TEST_PUBLIC_PATCH_SIGNATURE" "normal logs leaked PATCH signature" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" "(request-target): get" "secure debug missing GET signing string" &&
    _assert_contains "$MOCK_SECURE_DEBUG_LOG" "Authorization: Signature" "secure debug missing Authorization header" &&
    _assert_not_contains "$MOCK_SECURE_DEBUG_LOG" "TEST_PUBLIC_PASSPHRASE" "secure debug must not include passphrase value"
}

le_test_oci_rp_signing_failure_stops_zone_fallback() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "GET|$1|$_H2"
    case "$1" in
    *"/20180115/zones/example.com") printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}' ;;
    *) printf '%s' '{"status":404,"code":"NotAuthorizedOrNotFound"}' ;;
    esac
  }

  _post() {
    _dns_oci_mock_append signed_requests "PATCH|$2|$_H5|$1"
    printf '%s' '{}'
  }

  _sign() {
    cat >"$_DNS_OCI_MOCK_DIR/failed_signing_string"
    return 1
  }

  _mktemp() {
    _mock_tmp="$_DNS_OCI_MOCK_DIR/rp-failed-signing-key"
    : >"$_mock_tmp"
    printf '%s' "$_mock_tmp"
  }

  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_FAIL_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_FAIL_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "resource-principal signing failure should stop zone fallback" \
    dns_oci_add "_acme-challenge.www.dev.example.com" "fail-value" || return 1

  _dns_oci_mock_refresh_captures
  _install_oci_mock_stubs

  _assert_contains "$MOCK_ERROR_LOG" "resource principal signing failed" "signing failure diagnostic missing" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "/20180115/zones/example.com" "parent zone lookup must not be attempted after signing failure" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|" "PATCH must not be attempted after signing failure" &&
    _assert_not_contains "$MOCK_ERROR_LOG" "DNS Zone not found" "generic zone-not-found diagnostic must not hide signing failure" &&
    _assert_not_contains "$MOCK_ERROR_LOG$MOCK_DEBUG_LOG$MOCK_INFO_LOG" "TEST_FAIL_RPST" "signing failure logs leaked RPST" &&
    _assert_not_contains "$MOCK_ERROR_LOG$MOCK_DEBUG_LOG$MOCK_INFO_LOG" "TEST_FAIL_PRIVATE_PEM" "signing failure logs leaked private PEM" &&
    _assert_not_contains "$MOCK_ERROR_LOG$MOCK_DEBUG_LOG$MOCK_INFO_LOG" "Authorization:" "signing failure logs leaked Authorization"
}

le_test_oci_rp_passphrase_success() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "GET|$1|$_H2"
    printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}'
  }

  _post() {
    _dns_oci_mock_append signed_requests "PATCH|$2|$_H5|$1"
    printf '%s' '{}'
  }

  _sign() {
    _dns_oci_mock_append passphrase_failures "plain-sign-used"
    return 1
  }

  _oci_openssl_sign_with_passphrase() {
    _mock_key_file="$1"
    _mock_algorithm="$2"
    _mock_passphrase_file="$3"
    _dns_oci_mock_append passphrase_paths "$_mock_passphrase_file"
    _dns_oci_mock_append passphrase_values "$(cat "$_mock_passphrase_file")"
    _dns_oci_mock_append passphrase_algorithms "$_mock_algorithm"
    cat "$_mock_key_file" >"$_DNS_OCI_MOCK_DIR/passphrase_key"
    case "$_mock_key_file $_mock_algorithm $_mock_passphrase_file" in
    *TEST_INLINE_PASSPHRASE*) _dns_oci_mock_append passphrase_failures "passphrase leaked through argv" ;;
    esac
    printf '%s' "TEST_PASSPHRASE_SIGNATURE"
  }

  _mktemp() {
    mktemp "$_DNS_OCI_MOCK_DIR/rp-passphrase-signing.XXXXXX"
  }

  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_PASSPHRASE_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_PASSPHRASE_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="TEST_INLINE_PASSPHRASE"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "passphrase-backed RP signing should reach PATCH" \
    dns_oci_add "example.com" "passphrase-value" || return 1

  _dns_oci_mock_refresh_captures
  _mock_passphrase_paths="$(_dns_oci_mock_read passphrase_paths)"
  _mock_passphrase_values="$(_dns_oci_mock_read passphrase_values)"
  _mock_passphrase_failures="$(_dns_oci_mock_read passphrase_failures)"
  _mock_passphrase_key="$(_dns_oci_mock_read passphrase_key)"
  _install_oci_mock_stubs
  _normal_logs="$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG"

  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|" "passphrase success should reach PATCH" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" 'signature="TEST_PASSPHRASE_SIGNATURE"' "passphrase signature missing" &&
    _assert_contains "$_mock_passphrase_values" "TEST_INLINE_PASSPHRASE" "passphrase helper did not receive passphrase file content" &&
    _assert_eq "" "$_mock_passphrase_failures" "passphrase helper leaked or fell back to plain signing" &&
    _assert_eq "TEST_PASSPHRASE_PRIVATE_PEM" "$_mock_passphrase_key" "passphrase helper did not receive RP private PEM" &&
    _assert_not_contains "$_mock_passphrase_paths" "TEST_INLINE_PASSPHRASE" "passphrase value leaked through helper path" &&
    _assert_not_contains "$_normal_logs" "TEST_INLINE_PASSPHRASE" "normal logs leaked passphrase" &&
    _assert_not_contains "$MOCK_SECURE_DEBUG_LOG" "TEST_INLINE_PASSPHRASE" "secure debug leaked passphrase"
}

le_test_oci_rp_passphrase_failure_is_clean() {
  _reset_oci_mocks

  # shellcheck disable=SC1091
  . ./dnsapi/dns_oci.sh

  _get() {
    _dns_oci_mock_append signed_requests "GET|$1|$_H2"
    printf '%s' '{"id":"ocid1.dns-zone.oc1..example"}'
  }

  _post() {
    _dns_oci_mock_append signed_requests "PATCH|$2|$_H5|$1"
    printf '%s' '{}'
  }

  _sign() {
    _dns_oci_mock_append passphrase_failures "plain-sign-used"
    return 1
  }

  _oci_openssl_sign_with_passphrase() {
    _mock_passphrase_file="$3"
    _dns_oci_mock_append passphrase_paths "$_mock_passphrase_file"
    _dns_oci_mock_append passphrase_values "$(cat "$_mock_passphrase_file")"
    return 1
  }

  _mktemp() {
    mktemp "$_DNS_OCI_MOCK_DIR/rp-passphrase-failure.XXXXXX"
  }

  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="TEST_PASSPHRASE_FAIL_RPST"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="TEST_PASSPHRASE_FAIL_PRIVATE_PEM"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="TEST_INLINE_PASSPHRASE"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "passphrase signing failure should fail before PATCH" \
    dns_oci_add "example.com" "passphrase-failure-value" || return 1

  _dns_oci_mock_refresh_captures
  _mock_passphrase_paths="$(_dns_oci_mock_read passphrase_paths)"
  _install_oci_mock_stubs
  _normal_logs="$MOCK_DEBUG_LOG$MOCK_INFO_LOG$MOCK_ERROR_LOG"

  _assert_contains "$MOCK_ERROR_LOG" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE" "passphrase failure should name env var" &&
    _assert_contains "$MOCK_ERROR_LOG" "signing failed" "passphrase failure class missing" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|" "passphrase failure must not reach PATCH" &&
    _assert_not_contains "$_normal_logs" "TEST_INLINE_PASSPHRASE" "normal logs leaked failing passphrase" &&
    _assert_not_contains "$MOCK_SECURE_DEBUG_LOG" "TEST_INLINE_PASSPHRASE" "secure debug leaked failing passphrase" &&
    _assert_not_contains "$_normal_logs$MOCK_SECURE_DEBUG_LOG" "$_mock_passphrase_paths" "logs leaked passphrase path"
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

  _assert_failure "resource-principal-only auth should fail before PATCH when signing fails" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-current-state-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "unable to read OCI_CLI_TENANCY" "current-state missing tenancy error absent" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "resource-principal current state must not PATCH" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_RPST" "RPST path must not be saved" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM" "resource principal private key path must not be saved"
}

le_test_oci_auth_resource_principal_detected_boundary() {
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

  _assert_failure "resource-principal auth should stop on signing failure" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-boundary-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "_oci_auth_mode=resource_principal" "resource-principal mode was not recorded" &&
    _assert_contains "$MOCK_ERROR_LOG" "resource principal" "resource-principal diagnostic missing" &&
    _assert_contains "$MOCK_ERROR_LOG" "signing failed" "resource-principal signing failure missing" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "resource-principal boundary must not PATCH"
}

le_test_oci_auth_partial_key_falls_back_to_resource_principal() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  OCI_CLI_TENANCY="ocid1.tenancy.oc1..partial"
  unset OCI_CLI_USER
  OCI_CLI_REGION="us-ashburn-1"
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="/tmp/nonexistent-rpst"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="/tmp/nonexistent-private.pem"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "partial API-key config should fall back to RP signing failure" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-partial-key-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "OCI_CLI_USER" "partial-key diagnostic should name missing user" &&
    _assert_contains "$MOCK_ERROR_LOG" "OCI_CLI_KEY" "partial-key diagnostic should name missing key material" &&
    _assert_contains "$MOCK_ERROR_LOG" "_oci_auth_mode=resource_principal" "partial-key fallback did not select RP mode" &&
    _assert_contains "$MOCK_ERROR_LOG" "signing failed" "partial-key fallback did not report RP signing failure" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "resource principal values must not be persisted" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "partial-key RP boundary must not PATCH"
}

le_test_oci_auth_api_key_wins_over_resource_principal() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="/tmp/rpst.token"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="/tmp/private.pem"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_success "complete API-key config should win over complete RP env" \
    dns_oci_add "_acme-challenge.www.example.com" "api-key-wins-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "API-key-wins path did not reach PATCH" &&
    _assert_eq "api_key" "$_oci_auth_mode" "API-key config should select api_key mode" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_TENANCY=ocid1.tenancy.oc1..test" "tenancy was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_USER=ocid1.user.oc1..test" "user was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_REGION=us-ashburn-1" "region was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_KEY=-----BEGIN PRIVATE KEY-----" "key was not persisted" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL" "RP values must not be saved when API-key wins" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL" "RP values must not be cleared when API-key wins" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "OCI_RESOURCE_PRINCIPAL" "normal debug must not mention RP when API-key wins" &&
    _assert_not_contains "$MOCK_INFO_LOG" "OCI_RESOURCE_PRINCIPAL" "normal info must not mention RP when API-key wins"
}

le_test_oci_auth_oci_cli_config_file_primary() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  _mock_config_file="$_DNS_OCI_MOCK_DIR/oci-config"
  _mock_key_file="$_DNS_OCI_MOCK_DIR/oci-api-key.pem"
  : >"$_mock_config_file"
  printf '%s\n' "-----BEGIN PRIVATE KEY-----" "CONFIG_FILE_PRIVATE_KEY" "-----END PRIVATE KEY-----" >"$_mock_key_file"
  MOCK_OCI_READINI_TENANCY="ocid1.tenancy.oc1..config"
  MOCK_OCI_READINI_USER="ocid1.user.oc1..config"
  MOCK_OCI_READINI_REGION="us-phoenix-1"
  MOCK_OCI_READINI_KEY_FILE="$_mock_key_file"
  OCI_CLI_CONFIG_FILE="$_mock_config_file"
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE

  _assert_success "OCI CLI config file should remain an API-key auth source" \
    dns_oci_add "_acme-challenge.www.example.com" "config-file-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "config-file path did not reach PATCH" &&
    _assert_eq "api_key" "$_oci_auth_mode" "OCI CLI config file should select api_key mode" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_config_file|tenancy|DEFAULT" "tenancy was not read from config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_config_file|user|DEFAULT" "user was not read from config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_config_file|region|DEFAULT" "region was not read from config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_config_file|key_file|DEFAULT" "key_file was not read from config" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_CONFIG_FILE=$_mock_config_file" "non-default config path was not persisted" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_KEY=" "config key material was not persisted"
}

le_test_oci_auth_missing_saved_config_uses_default_config() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  mkdir -p "$HOME/.oci"
  _mock_default_config="$HOME/.oci/config"
  _mock_key_file="$HOME/.oci/oci-api-key.pem"
  : >"$_mock_default_config"
  printf '%s\n' "-----BEGIN PRIVATE KEY-----" "DEFAULT_CONFIG_PRIVATE_KEY" "-----END PRIVATE KEY-----" >"$_mock_key_file"
  _mock_account_conf OCI_CLI_CONFIG_FILE "/tmp/missing-oci-config"
  _mock_account_conf OCI_CLI_TENANCY "ocid1.tenancy.oc1..stale"
  _mock_account_conf OCI_CLI_USER "ocid1.user.oc1..stale"
  _mock_account_conf OCI_CLI_REGION "us-stale-1"
  _mock_account_conf OCI_CLI_KEY "STALE_SAVED_KEY"
  MOCK_OCI_READINI_TENANCY="ocid1.tenancy.oc1..default"
  MOCK_OCI_READINI_USER="ocid1.user.oc1..default"
  MOCK_OCI_READINI_REGION="us-ashburn-1"
  MOCK_OCI_READINI_KEY_FILE="'~/.oci/oci-api-key.pem'"
  unset OCI_CLI_CONFIG_FILE
  unset OCI_CLI_PROFILE
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE

  _assert_success "missing saved OCI config should fall back to default config" \
    dns_oci_add "_acme-challenge.www.example.com" "default-config-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "default-config fallback did not reach PATCH" &&
    _assert_eq "api_key" "$_oci_auth_mode" "default-config fallback should select api_key mode" &&
    _assert_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_CONFIG_FILE" "missing saved config path should be cleared" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_default_config|tenancy|DEFAULT" "tenancy was not read from default config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_default_config|user|DEFAULT" "user was not read from default config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_default_config|region|DEFAULT" "region was not read from default config" &&
    _assert_contains "$MOCK_READINI_KEYS" "$_mock_default_config|key_file|DEFAULT" "key_file was not read from default config" &&
    _assert_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_TENANCY" "stale saved tenancy should be cleared" &&
    _assert_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_USER" "stale saved user should be cleared" &&
    _assert_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_REGION" "stale saved region should be cleared" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_KEY=" "default key material was not persisted" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "STALE_SAVED_KEY" "stale saved key must not be reused"
}

le_test_oci_auth_resource_principal_does_not_persist() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="/tmp/rpst.token"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="/tmp/private.pem"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "resource-principal boundary should not persist RP values" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-no-persist-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "_oci_auth_mode=resource_principal" "RP mode should be observable in the boundary diagnostic" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "RP variable names must not be saved" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "RP variable names must not be cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "/tmp/rpst.token" "RPST path must not be saved" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "/tmp/private.pem" "private PEM path must not be saved" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "2.2" "RP version must not be saved" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "/tmp/rpst.token" "RPST path must not be cleared" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "RP no-persist boundary must not PATCH"
}

le_test_oci_auth_saved_config_survives_resource_principal_fallback() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  _mock_saved_config="$_DNS_OCI_MOCK_DIR/saved-oci-config"
  : >"$_mock_saved_config"
  _mock_account_conf OCI_CLI_CONFIG_FILE "$_mock_saved_config"
  _mock_account_conf OCI_CLI_TENANCY "ocid1.tenancy.oc1..saved"
  unset OCI_CLI_CONFIG_FILE
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
  OCI_RESOURCE_PRINCIPAL_RPST="/tmp/rpst.token"
  OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="/tmp/private.pem"
  OCI_RESOURCE_PRINCIPAL_REGION="us-ashburn-1"

  _assert_failure "saved API-key config should survive RP fallback" \
    dns_oci_add "_acme-challenge.www.example.com" "rp-saved-config-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "_oci_auth_mode=resource_principal" "saved-config fallback should select RP mode" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_CONFIG_FILE=$_mock_saved_config" "saved config path should remain saved" &&
    _assert_contains "$MOCK_SAVED_KEYS" "OCI_CLI_TENANCY=ocid1.tenancy.oc1..saved" "saved tenancy should remain saved" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_CONFIG_FILE" "saved config path must not be cleared" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_CLI_TENANCY" "saved tenancy must not be cleared" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "RP variable names must not be saved" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "saved-config RP fallback must not PATCH"
}

le_test_oci_auth_missing_reports_both_paths() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"
  unset OCI_CLI_TENANCY
  unset OCI_CLI_USER
  unset OCI_CLI_REGION
  unset OCI_CLI_KEY
  unset OCI_CLI_KEY_FILE
  unset OCI_RESOURCE_PRINCIPAL_VERSION
  unset OCI_RESOURCE_PRINCIPAL_RPST
  unset OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM
  unset OCI_RESOURCE_PRINCIPAL_REGION

  _assert_failure "missing all auth should report both key and RP paths" \
    dns_oci_add "_acme-challenge.www.example.com" "missing-both-value" || return 1

  _dns_oci_mock_refresh_captures
  _assert_contains "$MOCK_ERROR_LOG" "OCI_CLI_TENANCY" "missing-all auth should name key-based fields" &&
    _assert_contains "$MOCK_ERROR_LOG" "OCI_RESOURCE_PRINCIPAL_VERSION" "missing-all auth should name RP version" &&
    _assert_contains "$MOCK_ERROR_LOG" "OCI_RESOURCE_PRINCIPAL_RPST" "missing-all auth should name RPST" &&
    _assert_not_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/" "missing-all auth must not PATCH" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "missing-all auth must not save RP values" &&
    _assert_not_contains "$MOCK_CLEARED_KEYS" "OCI_RESOURCE_PRINCIPAL_" "missing-all auth must not clear RP values"
}

le_test_oci_rm_uses_auth_selector() {
  _reset_oci_mocks
  MOCK_OCI_ZONES="example.com"

  _assert_success "remove path should use API-key auth selector" \
    dns_oci_rm "_acme-challenge.www.example.com" "remove-selector-value" || return 1

  _dns_oci_mock_refresh_captures
  _remove_request=$(printf "%s\n" "$MOCK_SIGNED_REQUESTS" | grep '"operation":"REMOVE"')
  _assert_eq "api_key" "$_oci_auth_mode" "remove path should select api_key mode" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" "PATCH|/20180115/zones/example.com/records|" "remove selector path did not reach PATCH" &&
    _assert_contains "$MOCK_SIGNED_REQUESTS" '"operation":"REMOVE"' "remove selector payload missing REMOVE operation" &&
    _assert_not_contains "$_remove_request" '"ttl":' "remove selector payload must not include TTL" &&
    _assert_not_contains "$MOCK_SAVED_KEYS" "OCI_RESOURCE_PRINCIPAL" "remove selector must not save RP values" &&
    _assert_not_contains "$MOCK_DEBUG_LOG" "OCI_RESOURCE_PRINCIPAL" "remove selector must not normal-log RP values" &&
    _assert_not_contains "$MOCK_INFO_LOG" "OCI_RESOURCE_PRINCIPAL" "remove selector must not info-log RP values"
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

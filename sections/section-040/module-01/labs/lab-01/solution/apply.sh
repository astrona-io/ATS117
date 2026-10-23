#!/usr/bin/env bash
# Reference remediation, applied only by `astrona test`. Taken from solution.md — if one changes, change the other.
set -euo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

# ---- shared helpers (generated; keep identical in every environment) ----
HELM_VERSION="3.22.1"
OPENBAO_VERSION="2.7.1"
OPENBAO_CHART_VERSION="0.30.4"
NS="openbao"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

log() { echo "[ats-117] $*"; }

manifest_dir() {
  # Finds the environment's manifests folder whether the script runs from
  # its own folder, from the environment root, or with a copied layout.
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for candidate in "$here/../manifests" "./manifests" "$here/manifests"; do
    [ -d "$candidate" ] && { (cd "$candidate" && pwd); return 0; }
  done
  echo "manifests folder not found" >&2
  return 1
}

install_tools() {
  # Pins Helm and the bao CLI on the machine, the same way in every environment.
  local os arch work have
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
  work="$(mktemp -d)"
  have=""
  command -v helm >/dev/null 2>&1 && have=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//')
  if [ "$have" != "$HELM_VERSION" ]; then
    log "Downloading Helm ${HELM_VERSION} (${os}/${arch})..."
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-${os}-${arch}.tar.gz" | tar -xz -C "$work"
    install -m 0755 "$work/${os}-${arch}/helm" "$BIN_DIR/helm"
  fi
  have=""
  command -v bao >/dev/null 2>&1 && have=$(bao version 2>/dev/null | awk '{print $2}' | sed 's/^v//')
  if [ "$have" != "$OPENBAO_VERSION" ]; then
    log "Downloading the bao CLI ${OPENBAO_VERSION} (${os}/${arch})..."
    curl -fsSL "https://github.com/openbao/openbao/releases/download/v${OPENBAO_VERSION}/openbao_${OPENBAO_VERSION}_${os}_${arch}.tar.gz" \
      | tar -xz -C "$work" bao
    install -m 0755 "$work/bao" "$BIN_DIR/bao"
  fi
  rm -rf "$work"
}

add_coredns_rewrite() {
  # add_coredns_rewrite HOST TARGET: makes HOST resolve to TARGET inside the
  # cluster. The answer name is rewritten back to HOST, because Go programs
  # ignore DNS answers whose name differs from the question.
  local host="$1" target="$2" host_re target_re corefile
  if kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -q "$host"; then
    return 0
  fi
  host_re="$(printf '%s' "$host" | sed 's/\./\\\\./g')"
  target_re="$(printf '%s' "$target" | sed 's/\./\\\\./g')"
  log "Adding the CoreDNS rewrite for ${host}..."
  corefile="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
    | awk -v h="$host_re" -v t="$target" -v tr="$target_re" -v hn="$host" '/^[[:space:]]*kubernetes / && !done {
        print "    rewrite stop {"
        print "        name regex " h " " t
        print "        answer name " tr " " hn
        print "    }"
        done=1
      } {print}')"
  kubectl -n kube-system create configmap coredns --from-literal=Corefile="$corefile" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
}

helm_repo() {
  helm repo add openbao https://openbao.github.io/openbao-helm >/dev/null 2>&1 || true
  helm repo update openbao >/dev/null
}

install_openbao() {
  # install_openbao VALUES_FILE [extra helm args]: installs or upgrades the
  # 3-node cluster. No --wait: a sealed pod is never Ready, by design.
  local values="$1"; shift
  helm_repo
  helm upgrade --install openbao openbao/openbao --version "$OPENBAO_CHART_VERSION" \
    --namespace "$NS" --create-namespace --values "$values" "$@"
}

wait_started() {
  # wait_started POD: waits until the OpenBao container in POD runs.
  local pod="$1"
  for _ in $(seq 1 120); do
    [ "$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].started}' 2>/dev/null)" = "true" ] && return 0
    sleep 5
  done
  echo "pod $pod did not start" >&2
  return 1
}

root_token() { kubectl -n "$NS" get secret openbao-init -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d; }
unseal_key() { kubectl -n "$NS" get secret openbao-init -o jsonpath='{.data.unseal-key}' 2>/dev/null | base64 -d; }

bao_on() {
  # bao_on POD ARGS...: runs bao inside POD against its own listener with the
  # lab-only root token. BAO_TOKEN is set explicitly, because pods that use the
  # Transit seal also carry the seal's token in BAO_TOKEN.
  local pod="$1"; shift
  kubectl -n "$NS" exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$(root_token)" bao "$@"
}

seal_status() {
  # seal_status POD: prints the JSON of /v1/sys/seal-status as POD sees it.
  kubectl -n "$NS" exec -i "$1" -- env BAO_ADDR=http://127.0.0.1:8200 bao status -format=json 2>/dev/null || true
}

json_field() {
  # json_field KEY: reads a top-level string, number or boolean field from JSON on stdin.
  tr -d '\n' | sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" | head -1
}

is_sealed() { [ "$(seal_status "$1" | json_field sealed)" != "false" ]; }

unseal_pod() {
  # unseal_pod POD: enters the lab-only Shamir key on POD, if it is sealed.
  local pod="$1"
  wait_started "$pod"
  if is_sealed "$pod"; then
    kubectl -n "$NS" exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 bao operator unseal "$(unseal_key)" >/dev/null
  fi
}

init_cluster() {
  # init_cluster [shamir|auto] [VOTERS]: initializes openbao-0 with one lab-only
  # key share (Shamir) or one recovery share (auto-unseal), stores the key and
  # the root token in the Secret openbao-init, then unseals or waits for every
  # pod. Pods named in SKIP_UNSEAL stay sealed; VOTERS (default 3) is the
  # number of voters to wait for.
  local mode="${1:-shamir}" voters="${2:-3}" out key token
  wait_started openbao-0
  if ! kubectl -n "$NS" get secret openbao-init >/dev/null 2>&1; then
    log "Initializing OpenBao (${mode})..."
    if [ "$mode" = "auto" ]; then
      out="$(kubectl -n "$NS" exec -i openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao operator init -recovery-shares=1 -recovery-threshold=1 -format=json)"
      key="$(printf '%s' "$out" | tr -d '\n ' | sed -n 's/.*"recovery_keys_b64":\["\([^"]*\)".*/\1/p')"
    else
      out="$(kubectl -n "$NS" exec -i openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao operator init -key-shares=1 -key-threshold=1 -format=json)"
      key="$(printf '%s' "$out" | tr -d '\n ' | sed -n 's/.*"unseal_keys_b64":\["\([^"]*\)".*/\1/p')"
    fi
    token="$(printf '%s' "$out" | tr -d '\n ' | sed -n 's/.*"root_token":"\([^"]*\)".*/\1/p')"
    kubectl -n "$NS" create secret generic openbao-init \
      --from-literal=unseal-key="$key" --from-literal=root-token="$token"
  fi
  if [ "$mode" = "shamir" ]; then
    unseal_pod openbao-0
  fi
  wait_leader openbao-0
  # The StatefulSet starts its pods one at a time (OrderedReady): openbao-1
  # appears only after openbao-0 is ready, openbao-2 after openbao-1. Wait
  # for each pod the StatefulSet should run before unsealing it.
  local replicas
  replicas="$(kubectl -n "$NS" get statefulset openbao -o jsonpath='{.spec.replicas}')"
  for pod in openbao-1 openbao-2; do
    [ "${pod#openbao-}" -lt "${replicas:-1}" ] || continue
    case " ${SKIP_UNSEAL:-} " in *" $pod "*) continue ;; esac
    wait_started "$pod"
    if [ "$mode" = "shamir" ]; then unseal_pod "$pod"; fi
  done
  wait_voters "$voters"
}

wait_leader() {
  # wait_leader POD: waits until POD reports an active node.
  local pod="$1"
  for _ in $(seq 1 60); do
    seal_status "$pod" | grep -q '"leader_address": *"http' && return 0
    sleep 5
  done
  echo "no leader seen from $pod" >&2
  return 1
}

any_unsealed_pod() {
  for pod in openbao-0 openbao-1 openbao-2; do
    kubectl -n "$NS" get pod "$pod" >/dev/null 2>&1 || continue
    is_sealed "$pod" || { echo "$pod"; return 0; }
  done
  return 1
}

peers_json() {
  # peers_json: prints `bao operator raft list-peers -format=json` from an unsealed pod.
  local pod
  pod="$(any_unsealed_pod)" || return 1
  bao_on "$pod" operator raft list-peers -format=json
}

voter_count() { peers_json 2>/dev/null | tr -d '\n ' | grep -o '"voter":true' | wc -l | tr -d ' '; }

wait_voters() {
  # wait_voters N: waits until the Raft configuration has N voters.
  local want="$1"
  for _ in $(seq 1 60); do
    [ "$(voter_count)" = "$want" ] && return 0
    sleep 5
  done
  echo "expected $want voters, saw $(voter_count)" >&2
  return 1
}

leader_pod() {
  # leader_pod: prints the pod name of the Raft leader (node IDs are pod names).
  peers_json 2>/dev/null | tr -d '\n ' | grep -o '{[^{}]*"leader":true[^{}]*}' \
    | sed -n 's/.*"node_id":"\([^"]*\)".*/\1/p' | head -1
}

write_marker() {
  # write_marker: enables KV version 2 at secret/ and writes the marker secret
  # graders use to prove the data survived (it is never re-created).
  local pod
  pod="$(any_unsealed_pod)"
  bao_on "$pod" secrets enable -path=secret kv-v2 >/dev/null 2>&1 || true
  bao_on "$pod" kv put secret/platform/marker created-by=ats-117 >/dev/null
}

read_marker() {
  local pod
  pod="$(any_unsealed_pod)" || return 1
  bao_on "$pod" kv get -field=created-by secret/platform/marker 2>/dev/null
}

wait_unsealed() {
  # wait_unsealed POD: waits until POD reports sealed=false (auto-unseal).
  local pod="$1"
  wait_started "$pod"
  for _ in $(seq 1 60); do
    is_sealed "$pod" || return 0
    sleep 5
  done
  echo "pod $pod is still sealed" >&2
  return 1
}

restart_pod() {
  # restart_pod POD: deletes POD (the StatefulSet uses OnDelete, so this is how
  # a pod picks up new configuration) and waits for the new container to run.
  kubectl -n "$NS" delete pod "$1" --wait=true
  sleep 3
  wait_started "$1"
}

unseal_after_restart() {
  # unseal_after_restart POD shamir|auto|migrate
  case "$2" in
    shamir) unseal_pod "$1" ;;
    auto) wait_unsealed "$1" ;;
    migrate)
      wait_started "$1"
      kubectl -n "$NS" exec -i "$1" -- env BAO_ADDR=http://127.0.0.1:8200 \
        bao operator unseal -migrate "$(unseal_key)" >/dev/null
      ;;
  esac
}

rolling_restart() {
  # rolling_restart shamir|auto|migrate: restarts the standbys one at a time,
  # then steps the leader down and restarts it last. With "migrate" the
  # standbys get `unseal -migrate` and the old leader auto-unseals.
  local mode="$1" leader pod last_mode
  leader="$(leader_pod)"
  for pod in openbao-0 openbao-1 openbao-2; do
    [ "$pod" = "$leader" ] && continue
    restart_pod "$pod"
    unseal_after_restart "$pod" "$mode"
    wait_voters 3
  done
  bao_on "$leader" operator step-down >/dev/null
  sleep 15
  restart_pod "$leader"
  last_mode="$mode"
  [ "$mode" = "migrate" ] && last_mode=auto
  unseal_after_restart "$leader" "$last_mode"
  wait_voters 3
}

install_unsealer() {
  # install_unsealer: a second, single-node OpenBao in the namespace unsealer
  # that auto-unseals itself with the static seal and serves the Transit key
  # the main cluster uses. Stores an orphan, periodic token for the main
  # cluster in the Secret transit-seal-token (namespace openbao).
  local dir out token
  dir="$(manifest_dir)"
  kubectl create namespace unsealer --dry-run=client -o yaml | kubectl apply -f -
  if ! kubectl -n unsealer get secret unsealer-static-key >/dev/null 2>&1; then
    # A fresh 32-byte key per environment; never stored in the repository.
    kubectl -n unsealer create secret generic unsealer-static-key \
      --from-literal=key="$(openssl rand -hex 32)"
  fi
  helm_repo
  helm upgrade --install unsealer openbao/openbao --version "$OPENBAO_CHART_VERSION" \
    --namespace unsealer --values "$dir/unsealer-values.yaml"
  for _ in $(seq 1 120); do
    [ "$(kubectl -n unsealer get pod unsealer-0 -o jsonpath='{.status.containerStatuses[0].started}' 2>/dev/null)" = "true" ] && break
    sleep 5
  done
  if ! kubectl -n unsealer get secret unsealer-init >/dev/null 2>&1; then
    out="$(kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao operator init -recovery-shares=1 -recovery-threshold=1 -format=json)"
    token="$(printf '%s' "$out" | tr -d '\n ' | sed -n 's/.*"root_token":"\([^"]*\)".*/\1/p')"
    kubectl -n unsealer create secret generic unsealer-init --from-literal=root-token="$token"
  fi
  token="$(kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d)"
  for _ in $(seq 1 60); do
    kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao status >/dev/null 2>&1 && break
    sleep 5
  done
  unsealer_bao() { kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$token" bao "$@"; }
  unsealer_bao secrets enable transit >/dev/null 2>&1 || true
  unsealer_bao write -f transit/keys/autounseal >/dev/null
  printf '%s\n' 'path "transit/encrypt/autounseal" { capabilities = ["update"] }' \
    'path "transit/decrypt/autounseal" { capabilities = ["update"] }' \
    | unsealer_bao policy write autounseal - >/dev/null
  if ! kubectl -n "$NS" get secret transit-seal-token >/dev/null 2>&1; then
    kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
    out="$(unsealer_bao token create -orphan -period=24h -policy=autounseal -field=token)"
    kubectl -n "$NS" create secret generic transit-seal-token --from-literal=token="$out"
  fi
}

unsealer_token() { kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d; }

install_prometheus() {
  # install_prometheus: Prometheus v3.15.1 in the namespace monitoring, with
  # the scrape configuration in manifests/prometheus.yaml.
  kubectl apply -f "$(manifest_dir)/prometheus.yaml"
  kubectl -n monitoring rollout status deployment/prometheus --timeout=300s
}

prom_query() {
  # prom_query PROMQL: runs an instant query from the tester pod.
  kubectl -n clients exec -i deploy/tester -- curl -s -G \
    --data-urlencode "query=$1" http://prometheus.monitoring:9090/api/v1/query
}

prom_get() {
  # prom_get PATH: fetches a Prometheus API path from the tester pod.
  kubectl -n clients exec -i deploy/tester -- curl -s "http://prometheus.monitoring:9090$1"
}

tester_jq() {
  # tester_jq FILTER: runs jq inside the tester pod on stdin, so graders do not
  # need jq on the machine.
  kubectl -n clients exec -i deploy/tester -- jq -r "$1"
}

prom_scalar() {
  # prom_scalar PROMQL: prints the first value of an instant query, or nothing.
  prom_query "$1" | tester_jq '.data.result[0].value[1] // empty'
}
# ---- end of shared helpers ----

LEADER="$(leader_pod)"
API_KEY="$(bao_on "$LEADER" kv get -field=key secret/payments/api)"
kubectl -n "$NS" get configmap nightly-snapshot -o jsonpath='{.binaryData.nightly\.snap}' | base64 -d > /tmp/ats117-restore.snap
kubectl -n "$NS" exec -i "$LEADER" -- sh -c 'cat > /tmp/restore.snap' < /tmp/ats117-restore.snap
bao_on "$LEADER" operator raft snapshot restore /tmp/restore.snap
rm -f /tmp/ats117-restore.snap
sleep 15
wait_voters 3
bao_on "$(leader_pod)" kv put secret/payments/api key="$API_KEY" >/dev/null

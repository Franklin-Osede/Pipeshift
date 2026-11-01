#!/usr/bin/env bash
# Milestone 1 spike driver. Disposable tooling, not application code.
# Runs each fixture through the Jenkins converter inside a container with no
# network. Requests go through `docker exec`, so nothing is ever published.
set -euo pipefail

cd "$(dirname "$0")"
IMAGE="${IMAGE:-pipeshift-jenkins:spike}"
NAME="pipeshift-spike-$$"
URL="http://localhost:8080/pipeline-model-converter"
OUT=results
mkdir -p "$OUT"

trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
docker run -d --name "$NAME" \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  --tmpfs /var/jenkins_home:rw,size=1g,uid=1000,gid=1000,exec \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 512 \
  --memory 2g \
  --cpus 2 \
  --user 1000:1000 \
  "$IMAGE" >/dev/null

for _ in $(seq 1 180); do
  docker logs "$NAME" 2>&1 | grep -q 'Jenkins is fully up and running' && break
  sleep 1
done
ready_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
docker logs "$NAME" 2>&1 | grep -q 'Jenkins is fully up and running' || { echo "jenkins never became ready"; exit 1; }
echo "jenkins ready: startup_ms=$((ready_ms - start_ms))"

echo "--- sandbox checks (from inside the container):"
docker exec "$NAME" sh -c '
  echo "uid=$(id -u)"
  grep -E "^Cap(Eff|Bnd):" /proc/self/status
  grep NoNewPrivs /proc/self/status
  touch /usr/share/jenkins/x 2>&1 | head -1
  ls -la /var/run/docker.sock 2>&1 | head -1
  curl -s -m 5 -o /dev/null -w "egress http=%{http_code} exit=%{exitcode}\n" https://updates.jenkins.io/ || true
  ls /sys/class/net
'

post_file() { # endpoint field file
  docker exec -i "$NAME" curl -sS -X POST -w '\n%{http_code} %{time_total}\n' \
    --data-urlencode "$2@-" "$URL/$1" < "$3"
}

script_text() { # stdin: Groovy script, run via the script console on loopback
  docker exec -i "$NAME" sh -c '
    c=$(curl -sS -c /tmp/cj http://localhost:8080/crumbIssuer/api/json | sed -E "s/.*\"crumb\":\"([^\"]+)\".*/\1/")
    curl -sS -b /tmp/cj -H "Jenkins-Crumb: $c" -X POST --data-urlencode script@- http://localhost:8080/scriptText'
}

for f in fixtures/*.Jenkinsfile; do
  base=$(basename "$f" .Jenkinsfile)
  raw=$(post_file toJson jenkinsfile "$f")
  meta=$(printf '%s' "$raw" | tail -1)
  printf '%s' "$raw" | sed '$d' > "$OUT/$base.toJson.json"
  post_file validateJenkinsfile jenkinsfile "$f" | sed '$d' > "$OUT/$base.validate.json"
  echo "$base toJson: $meta"
done

echo "--- shim:"
for f in fixtures/*.Jenkinsfile; do
  base=$(basename "$f" .Jenkinsfile)
  { printf "def SRC = new String(Base64.decoder.decode('%s'), 'UTF-8')\n" "$(base64 -i "$f" | tr -d '\n')"
    cat parse-shim.groovy; } > /tmp/pipeshift-shim-$$.groovy
  script_text < /tmp/pipeshift-shim-$$.groovy > "$OUT/$base.shim.json"
  rm -f /tmp/pipeshift-shim-$$.groovy
  echo "$base: $(wc -c < "$OUT/$base.shim.json") bytes"
done

echo "--- round trip through toJenkinsfile:"
for base in 01-simple 02-medium 03-complex; do
  jq -c '.data.json' "$OUT/$base.toJson.json" > "/tmp/pipeshift-rt-$$.json"
  post_file toJenkinsfile json "/tmp/pipeshift-rt-$$.json" | sed '$d' \
    | jq -r '.data.jenkinsfile // .' > "$OUT/$base.roundtrip.Jenkinsfile"
  rm -f "/tmp/pipeshift-rt-$$.json"
done

echo "--- probe markers after toJson and shim (expect none):"
docker exec "$NAME" sh -c 'ls -la /tmp/pipeshift-probe-* 2>/dev/null || echo none'

echo "--- positive control: same ASTTest fixture, plain GroovyShell without the sandbox config:"
{ printf "def SRC = new String(Base64.decoder.decode('%s'), 'UTF-8')\n" "$(base64 -i fixtures/p8-compile-asttest.Jenkinsfile | tr -d '\n')"
  echo 'try { new GroovyShell().parse(SRC) } catch (Throwable t) { println "parse threw: " + t.class.name }'; } \
  | script_text
docker exec "$NAME" sh -c 'ls -la /tmp/pipeshift-probe-* 2>/dev/null || echo none'

docker stats --no-stream --format 'mem={{.MemUsage}} pids={{.PIDs}}' "$NAME"
docker logs "$NAME" > "$OUT/jenkins.log" 2>&1 || true

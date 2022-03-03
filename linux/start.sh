#!/bin/bash
set -e

if [ -z "$AZP_URL" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

if [ -z "$AZP_TOKEN_FILE" ]; then
  if [ -z "$AZP_TOKEN" ]; then
    echo 1>&2 "error: missing AZP_TOKEN environment variable"
    exit 1
  fi

  AZP_TOKEN_FILE=/agent/.token
  echo -n $AZP_TOKEN > "$AZP_TOKEN_FILE"
fi

unset AZP_TOKEN

if [ -n "$AZP_WORK" ]; then
  mkdir -p "$AZP_WORK"
fi

export AGENT_ALLOW_RUNASROOT="1"

cleanup() {  
  if [ -e config.sh ]; then
    print_header "Cleanup. Removing Azure Pipelines agent..."

    ./config.sh remove --unattended \
      --auth PAT \
      --token $(cat "$AZP_TOKEN_FILE")
  fi
}

print_header() {
  lightcyan='\033[1;36m'
  nocolor='\033[0m'
  echo -e "${lightcyan}$1${nocolor}"
}

# Let the agent ignore the token env variables
export VSO_AGENT_IGNORE=AZP_TOKEN,AZP_TOKEN_FILE

cd /agent
if [ -e /agent/config.sh ]; then
  print_header "Agent is pre-installed, skipping download..."
  skipDownload=1
fi

if [ $skipDownload -eq 0 ]; then
  print_header "Determining matching Azure Pipelines agent..."

  AZP_AGENT_RESPONSE=$(curl -LsS \
    -u user:$(cat "$AZP_TOKEN_FILE") \
    -H 'Accept:application/json;api-version=3.0-preview' \
    "$AZP_URL/_apis/distributedtask/packages/agent?platform=linux-x64")

  if echo "$AZP_AGENT_RESPONSE" | jq . >/dev/null 2>&1; then
    AZP_AGENTPACKAGE_URL=$(echo "$AZP_AGENT_RESPONSE" \
      | jq -r '.value | map([.version.major,.version.minor,.version.patch,.downloadUrl]) | sort | .[length-1] | .[3]')
  fi

  if [ -z "$AZP_AGENTPACKAGE_URL" -o "$AZP_AGENTPACKAGE_URL" == "null" ]; then
    echo 1>&2 "error: could not determine a matching Azure Pipelines agent - check that account '$AZP_URL' is correct and the token is valid for that account"
    exit 1
  fi

  print_header "Downloading and installing Azure Pipelines agent..."

  curl -LsS $AZP_AGENTPACKAGE_URL | tar -xz & wait $!
fi

source ./env.sh

print_header "Configuring Azure Pipelines agent..."

./config.sh --unattended \
  --agent "${AZP_AGENT_NAME:-$(hostname)}" \
  --url "$AZP_URL" \
  --auth PAT \
  --token $(cat "$AZP_TOKEN_FILE") \
  --pool "${AZP_POOL:-Default}" \
  --work "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula & wait $!

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# `exec` the node runtime so it's aware of TERM and INT signals
# AgentService.js understands how to handle agent self-update and restart
#exec ./externals/node/bin/node ./bin/AgentService.js interactive
if [ -z "$RUN_ONCE" ]; then
  print_header "Running Azure Pipelines agent..." && ./run.sh &
else
  print_header "Running Azure Pipelines agent once..." && ./run.sh --once &
fi
wait $!
cleanup

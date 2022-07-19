#!/bin/bash -eux

# These options can be overridden by env
CHAIN_ID="${CHAIN_ID:-local-test-umee}"
CHAIN_DIR="${CHAIN_DIR:-"/root/.umee"}"
DENOM="${DENOM:-uumee}"
STAKE_DENOM="${STAKE_DENOM:-$DENOM}"
CLEANUP="${CLEANUP:-0}"
LOG_LEVEL="${LOG_LEVEL:-info}"
SCALE_FACTOR="${SCALE_FACTOR:-000000}"
VOTING_PERIOD="${VOTING_PERIOD:-20s}"

# Default 1 account keys + 1 user key with no special grants
VAL0_KEY="val"
VAL0_MNEMONIC="copper push brief egg scan entry inform record adjust fossil boss egg comic alien upon aspect dry avoid interest fury window hint race symptom"
USER_KEY="user"
USER_MNEMONIC="pony glide frown crisp unfold lawn cup loan trial govern usual matrix theory wash fresh address pioneer between meadow visa buffalo keep gallery swear"
NEWLINE=$'\n'

hdir="$CHAIN_DIR"

NODE_BIN="umeed"

echo "--- Chain ID = $CHAIN_ID"
echo "--- Chain Dir = $CHAIN_DIR"
echo "--- Coin Denom = $DENOM"

# Folder for node
n0dir="$hdir"

# Home flag for folder
home0="--home $n0dir"

# Config directories for node
n0cfgDir="$n0dir/config"

# Config files for nodes
n0cfg="$n0cfgDir/config.toml"

# App config file for node
n0app="$n0cfgDir/app.toml"

# Common flags
kbt="--keyring-backend test"
cid="--chain-id $CHAIN_ID"

# Check if the data dir has been initialized already
if [[ ! -f "$n0cfgDir/genesis.json" ]]; then
  echo "====================================="
  echo "STARTING NEW CHAIN WITH GENESIS STATE"
  echo "====================================="

  echo "--- Creating $NODE_BIN validator with chain-id=$CHAIN_ID"

  # Build genesis file and create accounts
  if [[ "$STAKE_DENOM" != "$DENOM" ]]; then
    coins="1000000$SCALE_FACTOR$STAKE_DENOM,1000000$SCALE_FACTOR$DENOM"
  else
    coins="1000000$SCALE_FACTOR$DENOM"
  fi
  coins_user="1000000$SCALE_FACTOR$DENOM"

  echo "--- Initializing home..."

  # Initialize the home directory of node
  $NODE_BIN $home0 $cid init n0 &>/dev/null

  echo "--- Enabling node API"
  sed -i -s '108s/enable = false/enable = true/' $n0app

  # Generate new random key
  # $NODE_BIN $home0 keys add val $kbt &>/dev/null

  echo "--- Importing keys..."
  echo "$VAL0_MNEMONIC$NEWLINE"
  yes "$VAL0_MNEMONIC$NEWLINE" | $NODE_BIN $home0 keys add $VAL0_KEY $kbt --recover
  yes "$USER_MNEMONIC$NEWLINE" | $NODE_BIN $home0 keys add $USER_KEY $kbt --recover

  echo "--- Adding addresses..."
  $NODE_BIN $home0 keys show $VAL0_KEY -a $kbt
  $NODE_BIN $home0 keys show $VAL0_KEY -a --bech val $kbt
  $NODE_BIN $home0 keys show $USER_KEY -a $kbt
  $NODE_BIN $home0 add-genesis-account $($NODE_BIN $home0 keys show $VAL0_KEY -a $kbt) $coins &>/dev/null
  $NODE_BIN $home0 add-genesis-account $($NODE_BIN $home0 keys show $USER_KEY -a $kbt) $coins_user &>/dev/null



  echo "--- Patching genesis..."
  jq '.consensus_params["block"]["time_iota_ms"]="5000"
    | .app_state["crisis"]["constant_fee"]["denom"]="'$DENOM'"
    | .app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="'$DENOM'"
    | .app_state["mint"]["params"]["mint_denom"]="'$DENOM'"
    | .app_state["staking"]["params"]["bond_denom"]="'$DENOM'"
    | .app_state["gravity"]["params"]["bridge_ethereum_address"]="0x93b5122922F9dCd5458Af42Ba69Bd7baEc546B3c"
    | .app_state["gravity"]["params"]["bridge_chain_id"]="5"
    | .app_state["gravity"]["params"]["bridge_active"]=false
    | .app_state["gravity"]["delegate_keys"]=[{"validator":"umeevaloper1y6xz2ggfc0pcsmyjlekh0j9pxh6hk87ymuzzdn","orchestrator":"umee1y6xz2ggfc0pcsmyjlekh0j9pxh6hk87ymc9due","eth_address":"0xfac5EC50BdfbB803f5cFc9BF0A0C2f52aDE5b6dd"},{"validator":"umeevaloper1qjehhqdnc4mevtsumk6nkhm39nqrqtcy2f5k6k","orchestrator":"umee1qjehhqdnc4mevtsumk6nkhm39nqrqtcy2dnetu","eth_address":"0x02fa1b44e2EF8436e6f35D5F56607769c658c225"},{"validator":"umeevaloper1s824eseh42ndyawx702gwcwjqn43u89dhmqdw8","orchestrator":"umee1s824eseh42ndyawx702gwcwjqn43u89dhl8zld","eth_address":"0xd8f468c1B719cc2d50eB1E3A55cFcb60e23758CD"}]
    | .app_state["gravity"]["gravity_nonces"]["latest_valset_nonce"]="0"
    | .app_state["gravity"]["gravity_nonces"]["last_observed_nonce"]="0"
    | .app_state["gov"]["voting_params"]["voting_period"]="'$VOTING_PERIOD'"' \
      $n0cfgDir/genesis.json > $n0cfgDir/tmp_genesis.json && mv $n0cfgDir/tmp_genesis.json $n0cfgDir/genesis.json

  echo "--- Creating gentx..."
  $NODE_BIN $home0 gentx-gravity $VAL0_KEY 1000$SCALE_FACTOR$STAKE_DENOM 0x0Ca2adaC7e34EF5db8234bE1182070CD980273E8 umee1s9lg2vpjrwmyn93ftzkpkr750xjwzdp7a6e97h $kbt $cid
  $NODE_BIN $home0 collect-gentxs &>/dev/null

  echo "--- Validating genesis..."
  $NODE_BIN $home0 validate-genesis

  # Use perl for cross-platform compatibility
  # Example usage: $REGEX_REPLACE 's/^param = ".*?"/param = "100"/' config.toml
  REGEX_REPLACE="perl -i -pe"

  echo "--- Modifying config..."
  perl -i -pe 's|addr_book_strict = true|addr_book_strict = false|g' $n0cfg
  perl -i -pe 's|external_address = ""|external_address = "tcp://0.0.0.0:26657"|g' $n0cfg
  # perl -i -pe 's|external_address = ""|external_address = "tcp://localhost:26657"|g' $n0cfg
  perl -i -pe 's|"tcp://127.0.0.1:26657"|"tcp://0.0.0.0:26657"|g' $n0cfg
  # perl -i -pe 's|"tcp://127.0.0.1:26657"|"tcp://localhost:26657"|g' $n0cfg
  perl -i -pe 's|allow_duplicate_ip = false|allow_duplicate_ip = true|g' $n0cfg
  perl -i -pe 's|log_level = "info"|log_level = "'$LOG_LEVEL'"|g' $n0cfg
  perl -i -pe 's|timeout_commit = ".*?"|timeout_commit = "5s"|g' $n0cfg

  echo "--- Modifying app..."
  perl -i -pe 's|minimum-gas-prices = ""|minimum-gas-prices = "0uumee"|g' $n0app

  # Don't need to set peers if just one node, right?
else
  echo "===================================="
  echo "CONTINUING CHAIN FROM PREVIOUS STATE"
  echo "===================================="
fi # data dir check

# Start the instance
echo "--- Starting node..."

# $NODE_BIN $home0 start --grpc.address="localhost:9090" --grpc-web.enable=false --log_level info > $hdir.n0.log 2>&1 &
$NODE_BIN $home0 start --grpc.address="0.0.0.0:9090" --grpc-web.enable=true --log_level info

# Wait for chain to start
# echo "--- Waiting for chain to start..."
# sleep 4

# echo
# echo "Logs:"
# echo "  * tail -f $hdir.n0.log"
# echo
# echo "Env for easy access:"
# echo "export H1='--home $hdir/n0/'"
# echo
# echo "Command Line Access:"
# echo "  * $NODE_BIN --home $hdir/n0 status"

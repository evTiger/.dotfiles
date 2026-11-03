#!/usr/bin/env bash
set -u

# スクリプトのあるディレクトリ(= shimakaze/)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="$HOME/.ssh"

PUB="$SSH_DIR/keys/university/shimakaze/university_shimakaze_ed25519.pub"
HOSTS_FILE="$DIR/hosts.txt"
USER_NAME="shimakaze"
PREFIX="150.89.226"

command -v sshpass >/dev/null || { echo "sshpass が必要です"; exit 1; }

# パスワードを1回だけ入力(画面に表示されず、履歴にも残らない)
read -rs -p "shimakaze のパスワード: " SSHPASS
echo
export SSHPASS
trap 'unset SSHPASS' EXIT

ok=(); ng=()

targets=()
for n in $(cat "$HOSTS_FILE"); do targets+=("$PREFIX.$n"); done
targets+=("ckzemi.dedyn.io")

for host in "${targets[@]}"; do
  echo "=== $USER_NAME@$host ==="
  if sshpass -e ssh-copy-id -i "$PUB" \
       -o ConnectTimeout=5 \
       -o StrictHostKeyChecking=accept-new \
       "$USER_NAME@$host"; then
    ok+=("$host")
  else
    ng+=("$host")
  fi
done

echo
echo "成功: ${#ok[@]} 台"
echo "失敗: ${#ng[@]} 台"
for h in "${ng[@]}"; do echo "  - $h"; done

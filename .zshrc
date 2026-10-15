# ============================================================
# ~/.zshrc
# Shared Zsh configuration
# ============================================================


# ------------------------------------------------------------
# PATH
# ------------------------------------------------------------

# PATH/path must remain global even when .zshrc is sourced
# from inside a function such as snc().
typeset -gU path PATH

# User-local commands
path=("$HOME/.local/bin" $path)


# ------------------------------------------------------------
# Local environment
# ------------------------------------------------------------

# Some tools/installers create ~/.local/bin/env.
# Load it only when it exists.
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"


# ------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    plugins=(
        git
        zsh-autosuggestions
        zsh-syntax-highlighting
    )

    source "$ZSH/oh-my-zsh.sh"
fi


# ------------------------------------------------------------
# Starship
# ------------------------------------------------------------

if (( $+commands[starship] )); then
    if [[ -n "$SSH_CONNECTION" ]]; then
        export STARSHIP_CONFIG="$HOME/.config/starship-remote.toml"
    else
        export STARSHIP_CONFIG="$HOME/.config/starship.toml"
    fi

    eval "$(starship init zsh)"
fi


# ------------------------------------------------------------
# zoxide
# ------------------------------------------------------------

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi


# ------------------------------------------------------------
# zsh-autosuggestions
# ------------------------------------------------------------

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=117,bold"


# ------------------------------------------------------------
# Aliases
# ------------------------------------------------------------

# lsd
if (( $+commands[lsd] )); then
    alias ls='lsd'
    alias l='lsd -l --group-dirs=first'
    alias ll='lsd -l --group-dirs=first'
    alias la='lsd -a --group-dirs=first'
    alias lla='lsd -al --group-dirs=first'
    alias lt='lsd --tree --group-dirs=first'
fi

# bat
if (( $+commands[batcat] )); then
    alias bat='batcat'
fi

# WezTerm
if (( $+commands[wezterm.exe] )); then
    alias imgcat='wezterm.exe imgcat'
fi

# Neovim
if (( $+commands[nvim] )); then
    alias nv='nvim'
fi

# Antigravity
if (( $+commands[agy] )); then
    alias ag='clear && agy'
fi


# ------------------------------------------------------------
# NVM
# ------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"


# ------------------------------------------------------------
# snc
# ------------------------------------------------------------

snc() {
    # 引数はすべて無視し、常に単体で実体スクリプトを実行
    command snc
    local exit_status=$?

    # git pull がエラーなく正常終了した場合のみ、自動で source を実行
    if [ $exit_status -eq 0 ]; then
        echo "🔄 変更を適用するため、.zshrc を現在のターミナル環境に再読み込みしています..."
        source ~/.zshrc
        echo "✅ 設定の反映がすべて完了しました。"
    fi
}


# ------------------------------------------------------------
# tmux
# ------------------------------------------------------------

tmux() {
    # 引数がない、またはセッション作成・アタッチ系コマンドが含まれているか確認
    # (引数がある通常のtmuxコマンド、例えば tmux ls などはそのままスルーさせる)
    local is_session_cmd=0
    if [ $# -eq 0 ]; then
        is_session_cmd=1
    else
        for arg in "$@"; do
            if [[ "$arg" =~ ^(new-session|new|attach-session|attach|at)$ ]]; then
                is_session_cmd=1
                break
            fi
        done
    fi

    # セッション開始・アタッチ系の時だけ .tmux.conf をクレンジングして適用
    if [ "$is_session_cmd" -eq 1 ] && [ -f "$HOME/.tmux.conf" ]; then
        local tmp_conf="${TMPDIR:-/tmp}/.tmux.${USER}.conf"

        # \r (CR) を削除して一時ファイルにLF形式で保存
        tr -d '\r' < "$HOME/.tmux.conf" > "$tmp_conf" 2>/dev/null

        # 一時ファイルの設定を読み込ませて tmux を実行
        command tmux -f "$tmp_conf" "$@"

        # tmux 終了後に一時ファイルを削除
        local exit_status=$?
        rm -f "$tmp_conf"
        return $exit_status
    fi

    # それ以外のコマンド（tmux ls や tmux kill-server など）はそのまま実行
    command tmux "$@"
}


# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------

ssh() {
    if [[ "$*" == *"shimakaze@"* ]]; then
        if command -v sshpass &> /dev/null; then
            if [ -z "$SHIMAKAZE_PASS" ]; then
                printf "Password for shimakaze: "
                read -rs SHIMAKAZE_PASS
                echo ""
            fi

            local check_res
            check_res=$(command ssh -o NumberOfPasswordPrompts=0 -o StrictHostKeyChecking=ask "$@" 2>&1)
            local exit_status=$?

            if [[ "$check_res" == *"Host key verification failed"* ]]; then
                echo "$check_res" >&2
                unset SHIMAKAZE_PASS
                return $exit_status
            fi

            if [[ "$check_res" == *"Authenticity of host"* ]]; then
                command ssh "$@"
                return $?
            fi

            sshpass -p "$SHIMAKAZE_PASS" ssh "$@"
            SSH_STATUS=$?

            if [ $SSH_STATUS -ne 0 ]; then
                echo "⚠️ 接続に失敗したため、記憶したパスワードをクリアしました。"
                unset SHIMAKAZE_PASS
            fi
        else
            echo "sshpass is not installed. Please run: sudo apt install sshpass"
            command ssh "$@"
        fi
    else
        command ssh "$@"
    fi
}


# ------------------------------------------------------------
# ssht
#
# NOTE:
# この関数は既存の挙動を維持するため、
# 元の .zshrc のコードをそのまま使用。
# ------------------------------------------------------------

ssht() {
    local host=""
    local session=""
    local ssh_opts=()

    while [ $# -gt 0 ]; do
        case "$1" in
            # 値（引数）を1つ取る SSH 主要オプション
            -B|-b|-c|-D|-E|-e|-F|-I|-i|-J|-L|-l|-m|-O|-o|-P|-p|-R|-S|-W|-w)
                if [ $# -lt 2 ]; then
                    echo "⚠️  エラー: オプション $1 には引数が必要です。" >&2
                    return 1
                fi
                ssh_opts+=("$1" "$2")
                shift 2
                ;;

            # ssht関数自体のオプション終了フラグ (--)
            --)
                shift
                while [ $# -gt 0 ]; do
                    if [ -z "$host" ]; then
                        host="$1"
                    elif [ -z "$session" ]; then
                        session="$1"
                    else
                        echo "⚠️  エラー: 余分な引数が指定されています: $1" >&2
                        return 1
                    fi
                    shift
                done
                break
                ;;

            # 引数を取らないフラグ系オプション (-v, -4, -6, -A, -C, -X など)
            # および -p2222 や -oStrictHostKeyChecking=no などの結合形式
            -*)
                ssh_opts+=("$1")
                shift
                ;;

            # オプション以外の引数 (1つ目: ホスト, 2つ目: セッション名)
            *)
                if [ -z "$host" ]; then
                    host="$1"
                elif [ -z "$session" ]; then
                    session="$1"
                else
                    echo "⚠️  エラー: 余分な引数が指定されています: $1" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # セッション名が省略された場合はデフォルト値を使用
    session="${session:-tokunaga}"

    if [ -z "$host" ]; then
        echo "Usage: ssht [ssh_options] <host> [session_name]"
        return 1
    fi

    # tmuxターゲット指定で完全一致を要求するための = プレフィックス
    local target_session="=${session}"

    if [ ! -f "$HOME/.tmux.conf" ]; then
        echo "ℹ️  ローカルの ~/.tmux.conf が見つからないため、通常モードで接続します..."
        ssh -t "${ssh_opts[@]}" "$host" "
            ORIGINAL_PATH=\$( \${SHELL:-sh} -l -c 'echo \$PATH' )
            export PATH=\"\$ORIGINAL_PATH\"
            export TZ=\"Asia/Tokyo\"
            if command -v tmux &>/dev/null; then
                tmux new-session -A -s ${(q)session}
            else
                echo \"⚠️ リモート環境に tmux が見つからないため、通常のシェルを起動します。\"
                \${SHELL:-sh} -l
            fi
        "
        return 0
    fi

    echo "🚀 $host に接続中 (Session: $session / tmux 設定を自動同期しています)..."
    local tmux_conf_b64=$(tr -d '\r' < "$HOME/.tmux.conf" | base64 | tr -d '\n')

    # リモート側で実行するスクリプトを安全に組み立て
    ssh -t "${ssh_opts[@]}" "$host" "
        ORIGINAL_PATH=\$( \${SHELL:-sh} -l -c 'echo \$PATH' )
        export PATH=\"\$ORIGINAL_PATH\"
        export TZ=\"Asia/Tokyo\"

        if ! command -v tmux &>/dev/null; then
            echo \"⚠️ リモート環境に tmux がインストールされていないため、通常のシェルで接続します。\"
            \${SHELL:-sh} -l
            exit 0
        fi

        # セッションが存在しない場合のみ新規作成
        if ! tmux has-session -t ${(q)target_session} 2>/dev/null; then
            tmux new-session -d -s ${(q)session}
        fi

        # base64をデコードして設定を適用
        if command -v base64 &>/dev/null; then
            echo ${(q)tmux_conf_b64} | base64 -d | tmux source-file - 2>/dev/null
        elif command -v openssl &>/dev/null; then
            echo ${(q)tmux_conf_b64} | openssl base64 -d | tmux source-file - 2>/dev/null
        fi

        # ターゲットセッションにアタッチ
        tmux attach-session -t ${(q)target_session}
    "
}


# ------------------------------------------------------------
# Machine-specific configuration
# ------------------------------------------------------------

# 端末固有の設定が必要な場合は ~/.zshrc.local に記述する。
# ~/.zshrc.local はdotfilesのGit管理対象には含めない。
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

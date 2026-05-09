#!/usr/bin/env bash
set -euo pipefail

# Ajuste estes valores se for usar o script em outro repositorio/conta.
GIT_EMAIL="${GIT_EMAIL:-rtech.thiago@gmail.com}"
GIT_NAME="${GIT_NAME:-RobsonThiago}"
SSH_ALIAS="${SSH_ALIAS:-github-rtech}"
SSH_HOST="${SSH_HOST:-github.com}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_rtech}"
REPO_SSH_PATH="${REPO_SSH_PATH:-rtechthiago/app_sync.git}"
REMOTE_NAME="${REMOTE_NAME:-origin}"

log() {
  printf '\n==> %s\n' "$1"
}

ensure_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Erro: execute este script dentro de um repositorio Git.\n' >&2
    exit 1
  fi
}

ensure_ssh_key() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ -f "$SSH_KEY" ]; then
    log "Chave SSH ja existe: $SSH_KEY"
    return
  fi

  log "Criando nova chave SSH: $SSH_KEY"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY"
}

ensure_ssh_config() {
  local config_file="$HOME/.ssh/config"

  touch "$config_file"
  chmod 600 "$config_file"

  if grep -qE "^[[:space:]]*Host[[:space:]]+$SSH_ALIAS([[:space:]]|\$)" "$config_file"; then
    log "Alias SSH ja existe no config: $SSH_ALIAS"
    return
  fi

  log "Adicionando alias SSH no $config_file: $SSH_ALIAS"
  {
    printf '\nHost %s\n' "$SSH_ALIAS"
    printf '    HostName %s\n' "$SSH_HOST"
    printf '    User git\n'
    printf '    IdentityFile %s\n' "$SSH_KEY"
    printf '    IdentitiesOnly yes\n'
    printf '    AddKeysToAgent yes\n'
  } >> "$config_file"
}

add_key_to_agent() {
  log "Adicionando chave ao ssh-agent"

  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    eval "$(ssh-agent -s)" >/dev/null
  fi

  ssh-add "$SSH_KEY"
}

configure_git_repo() {
  local remote_url="git@$SSH_ALIAS:$REPO_SSH_PATH"

  log "Configurando usuario local do Git"
  git config user.email "$GIT_EMAIL"
  git config user.name "$GIT_NAME"

  log "Configurando remoto $REMOTE_NAME: $remote_url"
  if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    git remote set-url "$REMOTE_NAME" "$remote_url"
  else
    git remote add "$REMOTE_NAME" "$remote_url"
  fi
}

show_public_key() {
  log "Chave publica para cadastrar no GitHub, se ainda nao estiver cadastrada"
  cat "$SSH_KEY.pub"
}

validate_access() {
  log "Remotos configurados"
  git remote -v

  log "Testando autenticacao SSH"
  ssh -T "git@$SSH_ALIAS" || true

  log "Validando acesso ao repositorio"
  git ls-remote "$REMOTE_NAME" >/dev/null

  printf '\nValidacao concluida com sucesso.\n'
}

main() {
  ensure_git_repo
  ensure_ssh_key
  ensure_ssh_config
  add_key_to_agent
  configure_git_repo
  show_public_key
  validate_access
}

main "$@"

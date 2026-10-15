#!/usr/bin/env bash
# M1: one authoritative instance-path resolver; sourcing has no side effects.
# Requires Bash 4+, Python 3 for symlink-safe canonical path resolution.
M1_KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
m1_abs() {
  local input="${1:-}"
  [[ -n "$input" ]] || return 2
  # GNU realpath -m canonicalizes existing symlinks, even if the final path is absent.
  # Unlike spawning Python for every path check, this keeps offline tests fast.
  realpath -m -- "$input"
}
m1_is_under() {
  case "$1" in "$2"|"$2"/*) return 0;; *) return 1;; esac
}
m1_resolve() {
  local requested="${1:-${OPERATOR_HOME:-}}" legacy="${2:-0}" env_override="${3:-${OPERATOR_ENV:-}}"
  if [[ -z "$requested" ]]; then
    if [[ "$legacy" = 1 ]]; then requested="$M1_KIT_ROOT";
    else echo 'M1_ERR: 请使用 --home 指定 Kit 外部的实例目录' >&2; return 2; fi
  fi
  M1_HOME="$(m1_abs "$requested")" || return 2
  if m1_is_under "$M1_HOME" "$M1_KIT_ROOT" && { [[ "$legacy" != 1 ]] || [[ "$M1_HOME" != "$M1_KIT_ROOT" ]]; }; then
    echo "M1_ERR: 外部实例不得位于 KIT_ROOT 内: $M1_HOME" >&2; return 3
  fi
  if [[ "$M1_HOME" != "$M1_KIT_ROOT" ]] && m1_is_under "$M1_KIT_ROOT" "$M1_HOME"; then
    echo "M1_ERR: 实例根不能是 Kit 的父目录: $M1_HOME" >&2; return 3
  fi
  # Explicit config selection and default config must resolve to a file within the instance.
  M1_ENV="$(m1_abs "${env_override:-$M1_HOME/operator.env}")" || return 2
  if ! m1_is_under "$M1_ENV" "$M1_HOME"; then
    echo "M1_ERR: 配置文件必须在实例目录内: $M1_ENV" >&2; return 3
  fi
  export M1_KIT_ROOT M1_HOME M1_ENV
}
m1_verify_child() {
  local name="$1" candidate="$2" canonical
  [[ -n "$candidate" ]] || { echo "M1_ERR: $name 不能为空" >&2; return 3; }
  canonical="$(m1_abs "$candidate")" || return 3
  if [[ "$canonical" == "$M1_HOME" ]] || ! m1_is_under "$canonical" "$M1_HOME"; then
    echo "M1_ERR: $name 必须在 OPERATOR_HOME 内：$candidate -> $canonical" >&2
    return 3
  fi
}

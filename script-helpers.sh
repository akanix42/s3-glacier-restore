#!/usr/bin/env bash
#
# helper functions for shell scripts
# source: https://gist.github.com/akanix42/f9fdb2e256d0c21dc6e657bb958da936

declare -A LOG_LEVELS=(
  ["trace"]=1
  ["debug"]=2
  ["info"]=3
  ["warn"]=4
  ["error"]=5
  ["off"]=6
)

LOG_LEVEL="${LOG_LEVEL:-error}"

function check_binaries() {
  local binaries=("$@")
  local is_command_not_found=
  log_info '... checking for required binaries'
  for binary in "${binaries[@]}"; do
    if ! command -v "${binary}" >/dev/null; then
      log_error "command not found: ${binary}"
      is_command_not_found=1
    fi
  done

  return ${is_command_not_found}
}

#######################################
# check_required_variables $1 $2 ... $N $N+1
# Arguments:
# $1 $2 ... $N $N+1
#   pairs of required variables and their descriptions
# Outputs:
#   a message about which variables are not set
# Example:
#   check_required_variables FOO 'anything you want it to be'
# Output:
#   FOO is required; it should be anything you want it to be
# If the variable has an alternate name, that can be supplied using a colon separator:
# Example:
#   check_required_variables FOO:$1 'anything you want it to be'
# Output:
#   FOO ($1) is required; it should be anything you want it to be
function check_required_variables() {
  local _is_missing_required_variables=
  log_info 'checking required variables'

  local _variable
  local _alternate_variable
  local _message
  local _value
  while (($# > 1)); do
    _variable="${1%:*}"
    _alternate_variable=" (${1#*:})"
    _message="${2}"
    shift 2

    if [[ "${_alternate_variable}" == " (${_variable})" ]]; then
      _alternate_variable=''
    fi
    _value="${!_variable:-}"

    if [[ -z "${_value}" ]]; then
      log_error -e "${_variable}${_alternate_variable} is required; it should be ${_message}"

      _is_missing_required_variables=1
    else
      log_variable "${_variable}"
    fi
  done
  if [[ -n "${_is_missing_required_variables}" ]]; then
    log_error 'required variables not set correctly!'
    return 1
  fi
}

function get_os() {
  case "$(uname -s)" in
    Darwin)
      echo 'osx'
      ;;
    Linux)
      echo 'linux'
      ;;
    CYGWIN* | MINGW32* | MSYS* | MINGW*)
      echo 'windows'
      ;;
    *)
      echo 'other'
      ;;
  esac
}

################################################################################
# Run curl with script-friendly parameters
#
# Globals:
#   CURL_RESPONSE
#   CURL_STATUS_CODE
# Arguments:
#   $@ - arguments to pass to the curl command
# Outputs:
#   the curl output
# Returns:
#   1 if the status code is not 2XX
################################################################################
curl_cmd() {
  local result
  result="$(
    curl \
      --silent \
      --show-error \
      --location \
      --write-out "\n%{http_code}" \
      "$@"
  )"

  local status_code
  status_code="$(echo "${result}" | tail -n 1)"
  #shellcheck disable=SC2034
  CURL_STATUS_CODE="${status_code}"
  CURL_RESPONSE="$(echo "${result}" | sed '$d')"
  echo "${CURL_RESPONSE}"

  if ((status_code < 200 || status_code >= 300)); then
    return 1
  fi
}

#######################################
# Use for ALL log messages so that STDOUT is reserved for parsable application
# output such as cat, helm templates, etc.
# log $1 ... $N
# Arguments:
# $1 $2 ... $N $N+1
#   arguments to be passed to echo
# Outputs:
#   the output of the echo command redirected to STDERR
# Example:
#   log -e 'hello\n... world'
# Output:
#   hello
#   ... world
function log() {
  local args=()
  if [[ -z "${LOG_PREFIX:-}" ]]; then
    args=("$@")
  else
    while (($# > 0)); do
      local arg="$1"
      if [[ "${arg}" =~ ^-[^-] ]]; then
        args+=("${arg}")
      else
        args+=("${LOG_PREFIX}")
        break
      fi
      shift
    done
    args+=("$@")
  fi
  echo "${args[@]}" >&2
}

#######################################
# Get the numeric representation of the current or specified log level
# Errors if the log level does not exist
# get_log_level [$1]
# Arguments:
# $1
#   (optional) the log level to look up
# Outputs:
#   a number representing the log level
# Example:
#   set_log_level info
#   get_log_level
#   get_log_level debug
#   get_log_level foo
# Output:
#   3
#   2
#   (TO STDERR): unable to get nonexistent log level
function get_log_level() {
  local level="${1:-${LOG_LEVEL}}"
  level="${level,,}"
  if [[ -z "${LOG_LEVELS[${level}]+exists}" ]]; then
    log_error "unable to get nonexistent log level"
    return 1
  fi

  echo "${LOG_LEVELS[${level}]}"
}

#######################################
# Set the current log level
# Errors if the log level does not exist
# set_log_level $1
# Arguments:
# $1
#   the log level to set
# Outputs:
#   None
# Example:
#   set_log_level info
# Output:
#   None
function set_log_level() {
  local level="${1,,}"
  if [[ -z "${LOG_LEVELS[${level}]}" ]]; then
    log_error "unable to set log level to nonexistest level ${level}"
    return 1
  fi

  LOG_LEVEL="${level}"
}

#######################################
# Log all arguments at LOG_LEVEL <= debug
# See documentation for the log function for more information
function log_debug() {
  if (($(get_log_level) <= $(get_log_level 'debug'))); then
    LOG_PREFIX='~~~' log "$@"
  fi
}

#######################################
# Log all arguments at LOG_LEVEL <= error
# See documentation for the log function for more information
function log_error() {
  if (($(get_log_level) <= $(get_log_level 'error'))); then
    LOG_PREFIX='!!!' log "$@"
  fi
}

#######################################
# Log all arguments at LOG_LEVEL <= info
# See documentation for the log function for more information
function log_info() {
  if (($(get_log_level) <= $(get_log_level 'info'))); then
    LOG_PREFIX='...' log "$@"
  fi
}

#######################################
# Log all arguments with the progress prefix (...)
# See documentation for the log function for more information
function log_progress() {
  LOG_PREFIX='...' log "$@"
}

#######################################
# Log all arguments at LOG_LEVEL <= trace
# See documentation for the log function for more information
function log_trace() {
  if (($(get_log_level) <= $(get_log_level 'trace'))); then
    LOG_PREFIX='***' log "$@"
  fi
}

#######################################
# Log all arguments at LOG_LEVEL <= warn
# See documentation for the log function for more information
function log_warn() {
  if (($(get_log_level) <= $(get_log_level 'warn'))); then
    LOG_PREFIX='???' log "$@"
  fi
}

#######################################
# Log the named variable as well as it's value
# log_variable <variable>
# Arguments:
# $1
#   the name of the variable
# Outputs:
#   the variable name and value
# Example:
#   foo=bar log_variable foo
# Output:
#   foo: bar
function log_variable() {
  local variable="$1"
  local value="${!variable}"

  log_debug "${variable}:" "${value[@]}"
}

#######################################
# Prompt the user for a case-insensitive y/n response
# prompt_yes_no <message>
# Arguments:
# $1
#   the prompt to display
# Outputs:
#   the variable name and value
# Example:
#   foo=bar log_variable foo
# Output:
#   foo: bar
function prompt_yes_no() {
  local prompt="$1"
  # shellcheck disable=SC2016
  check_required_variables \
    'prompt:$1' 'the message to display'
  read -p "<<< ${prompt} (y/n) " -n 1 -r
  if [[ "${REPLY}" =~ ^[^Yy]$ ]]; then
    echo
    return 1
  fi
  echo
}

#######################################
# realpath $1
# Arguments:
# $1
#   a path (relative or absolute)
# Outputs:
#   the absolute path after symlinks are fully resolved
# Example:
#   realpath ../../foo
# Output:
#   /path/to/foo
function realpath() {
  python -c 'import os; import sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

#######################################
# Log the calling function name and it's arguments at LOG_LEVEL <= trace
# trace_function $1 $2 ... $N $N+1
# Arguments:
# $1 $2 ... $N $N+1
#   the arguments passed to the calling function
# Outputs:
#   the calling function name and it's arguments
# Example:
#   # from function foo, called with arguments: 1 2
#   trace_function "$@"
# Output:
#   foo "1" "2"
function trace_function() {
  local args_string=
  if (($# > 0)); then
    args_string="$(printf '"%s" ' "$@")"
  fi
  log_trace "${FUNCNAME[1]}" "${args_string}"
}

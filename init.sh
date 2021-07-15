#!/usr/bin/env bash

source script-helpers.sh

export env="${env:-}"
export tenant="${tenant:-}"
export bucket_name="${bucket_name:-}"
export bucket_suffix="${bucket_suffix:-}"

if
  ! check_required_variables \
    'env' 'dev/stg/prd' \
    'tenant' 'the tenant to target' \
    'bucket_suffix' 'the s3 bucket suffix' \
    'bucket_name' 'the s3 bucket to use'
then
  exit 1
fi

file_prefix="${tenant}-${env}/files"
mkdir -p "$(dirname "${file_prefix}")"

log_error() {
  printf '! %s' "$@" >&2
}

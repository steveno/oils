# Usage:
#   source test/common.sh

# Include guard.
test -n "${__TEST_COMMON_SH:-}" && return
readonly __TEST_COMMON_SH=1

# Used by test/{gold,osh-usage,stateful,wild-runner}
OSH=${OSH:-bin/osh}

# For xargs -P in spec-runner.sh, wild-runner.sh.
MAX_PROCS=${MAX_PROCS:-$(( $(nproc) - 1 ))}

readonly R_PATH=~/R  # Like PYTHONPATH, but for running R scripts

log() {
  echo "$@" 1>&2
}

die() {
  log "$@"
  exit 1
}

fail() {
  echo 'TEST FAILURE  ' "$@"
  exit 1
}

assert() {
  ### Must be run with errexit off

  if ! test "$@"; then
    # note: it's extremely weird that we use -1 and 0, but that seems to be how
    # bash works.
    die "${BASH_SOURCE[-1]}:${BASH_LINENO[0]}: assert '$@' failed"
  fi
}

run-task-with-status() {
  ### Run a process and write a file with status and time

  local out_file=$1
  shift

  # spec/wild tests only need two digits of precision
  benchmarks/time_.py \
    --tsv \
    --time-fmt '%.2f' \
    --output $out_file \
    -- "$@" || true  # suppress failure

  # TODO: Use rows like this with oil
  # '{"status": %x, "wall_secs": %e, "user_secs": %U, "kernel_secs": %S}' \
}

list-test-funcs() {
  ### Shell funcs that start with 'test-' are cases that will pass or fail
  compgen -A function | egrep '^test-' 
}

run-test-funcs() {
  # for correct error handling, and to mutate $i
  #
  # Note: when I ran $t rather than $0 t, I seemed to tickle a bash lastpipe bug like this:
  # https://www.spinics.net/lists/dash/msg01918.html
  # I got a 127 exit code with no explanation.
  shopt -s lastpipe

  local i=0
  local status=0

  list-test-funcs | while read t; do
    echo "*** Running $t"

    set +o errexit
    $0 $t
    status=$?
    set -o errexit

    if test $status -ne 0; then
      log "FAIL  $t"
      exit 1
    fi

    log "OK  $t"
    i=$((i + 1))
  done

  echo
  echo "$0: $i tests passed."
}

# Used by cpp/TEST.sh and mycpp/TEST.sh
# Compare with run-test-funcs in test/common.sh

run-test() {
  local bin=$1
  local compiler=$2
  local variant=$3
  shift 3

  local rel_path=${bin#'_bin/'}
  local log_dir="_test/$(dirname $rel_path)"
  mkdir -p $REPO_ROOT/$log_dir  # abs path

  local name=$(basename $bin)
  export LLVM_PROFILE_FILE="$REPO_ROOT/$log_dir/$name.profraw"

  local log=$log_dir/$name.log
  log "RUN $bin > $log"

  set +o errexit
  $bin "$@" > $REPO_ROOT/$log 2>&1
  local status=$?
  set -o errexit

  if test $status -eq 0; then
    log "OK $bin"
  else
    echo
    echo "=== $REPO_ROOT/$log ==="
    echo
    cat $REPO_ROOT/$log
    echo
    die "$bin failed with code $status"
  fi
}

run-with-log-wrapper() {
  ### Same as above, except you specify the log file
  local bin=$1
  local log=$2
  shift 2

  mkdir -p $(dirname $log)
  log "RUN $bin > $log"

  set +o errexit
  $bin "$@" > $log 2>&1
  local status=$?
  set -o errexit

  if test $status -eq 0; then
    log "OK $bin"
  else
    echo
    cat $log
    echo
    die "FAIL: $bin failed with code $status"
  fi
}

# A quick and dirty function to show logs
run-other-suite-for-release() {
  local suite_name=$1
  local func_name=$2
  local out=${3:-_tmp/other/${suite_name}.txt}

  mkdir -p $(dirname $out)

  echo
  echo "*** Running test suite '$suite_name' ***"
  echo

  # I want to handle errors in $func_name while NOT changing its semantics.
  # This requires a separate shell interpreter starts with $0, not just a
  # separate process.  I came up with this fix in gold/errexit-confusion.sh.

  local status=0

  set +o errexit
  $0 $func_name >$out 2>&1
  status=$?  # pipefail makes this work.
  set -o errexit

  if test $status -eq 0; then
    echo
    log "Test suite '$suite_name' ran without errors.  Wrote '$out'"
  else
    echo
    die "Test suite '$suite_name' failed (running $func_name, wrote '$out')"
  fi
}

date-and-git-info() {
  date
  echo

  if test -d .git; then
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    local hash
    hash=$(git rev-parse $branch)

    echo "oil repo: $hash on branch $branch"
  else
    echo "(not running from git repository)"
  fi
  echo
}

html-head() {
  PYTHONPATH=. doctools/html_head.py "$@"
}

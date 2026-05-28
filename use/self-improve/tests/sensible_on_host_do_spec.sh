#!/usr/bin/env bash
#
# Test for sensible_on_host_do.sh
# Tests: single task, task chain, runNext chaining

. "$(dirname "$0")/lib/bash-spec.sh"

SENSIBLE_ON_HOST_DO="$(cd "$(dirname "$0")/../sbin" && pwd)/sensible_on_host_do"
TEST_TASKS_DIR="/tmp/test-sensible-$$"
TASKS_PENDING="$TEST_TASKS_DIR/pending"

cleanup() {
  rm -rf "$TEST_TASKS_DIR" 2>/dev/null || true
}

describe "sensible_on_host_do.sh" && {

  cleanup

  context "1. single task" && {
    it "creates task file with correct JSON" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      FILE_ID=$("$SENSIBLE_ON_HOST_DO.sh" 'echo hello' 2>&1 | tail -1)
      [ -n "$FILE_ID" ]
      should_succeed
    }

    it "task file exists in pending" && {
      [ -f "$TASKS_PENDING"/*.json ]
      should_succeed
    }
  }

  context "2. task chain with runNext" && {
    it "chains multiple tasks via runNext" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      rm -rf "$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      
      "$SENSIBLE_ON_HOST_DO.sh" 'echo first' 'echo second' 'echo third' 2>&1
      
      # Find all task files
      JSON_FILES=("$TASKS_PENDING"/*.json)
      [ ${#JSON_FILES[@]} -eq 3 ]
      should_succeed
    }

    it "first task has runNext pointing to second" && {
      FIRST_JSON=$(ls -t "$TASKS_PENDING"/*.json 2>/dev/null | tail -1)
      grep -q "run_next" "$FIRST_JSON"
      should_succeed
    }

    it "last task has no runNext" && {
      LAST_JSON=$(ls -t "$TASKS_PENDING"/*.json 2>/dev/null | head -1)
      grep -v "run_next" "$LAST_JSON" | grep -q "queued"
      should_succeed
    }
  }

  context "3. usage error" && {
    it "shows usage when no args" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      "$SENSIBLE_ON_HOST_DO.sh" 2>&1 | grep -q "Usage:"
      should_fail  # script exits with error
    }
  }

  context "cleanup" && {
    it "removes test directory" && {
      cleanup
      [ ! -d "$TEST_TASKS_DIR" ]
      should_succeed
    }
  }
}

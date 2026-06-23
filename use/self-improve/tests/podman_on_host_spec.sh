#!/usr/bin/env bash
#
# Test for podman_on_host.sh
# Tests: commit, commit_and_switch, restart, switch, rmi commands

. "$(dirname "$0")/lib/bash-spec.sh"

PODMAN_ON_HOST="$(cd "$(dirname "$0")/../shared-sbin" && pwd)/podman_on_host.sh"
SENSIBLE_ON_HOST_DO="$(cd "$(dirname "$0")/../shared-sbin" && pwd)/sensible_on_host_do.sh"
TEST_TASKS_DIR="/tmp/test-podman-$$"
TASKS_PENDING="$TEST_TASKS_DIR/pending"

cleanup() {
  rm -rf "$TEST_TASKS_DIR" 2>/dev/null || true
}

describe "podman_on_host.sh" && {

  cleanup

  context "1. commit command" && {
    it "queues rmi, tag, and commit tasks" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      
      "$PODMAN_ON_HOST" commit test-container my-tag 2>&1
      
      # Should create 3 task files
      JSON_FILES=("$TASKS_PENDING"/*.json)
      [ ${#JSON_FILES[@]} -eq 3 ]
      should_succeed
    }
  }

  context "2. commit_and_switch command" && {
    it "queues rmi, tag, commit, and restart tasks" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      rm -rf "$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      
      "$PODMAN_ON_HOST" commit_and_switch test-container my-tag 2>&1
      
      # Should create 4 task files
      JSON_FILES=("$TASKS_PENDING"/*.json)
      [ ${#JSON_FILES[@]} -eq 4 ]
      should_succeed
    }
  }

  context "3. restart command" && {
    it "queues restart task" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      rm -rf "$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      
      "$PODMAN_ON_HOST" restart test-container 2>&1
      
      # Should create 1 task file
      JSON_FILES=("$TASKS_PENDING"/*.json)
      [ ${#JSON_FILES[@]} -eq 1 ]
      should_succeed
    }
  }

  context "4. rmi command" && {
    it "queues rmi task" && {
      export HOST_TASKS_DIR="$TEST_TASKS_DIR"
      rm -rf "$TEST_TASKS_DIR"
      mkdir -p "$TASKS_PENDING"
      
      "$PODMAN_ON_HOST" rmi localhost/test:image 2>&1
      
      # Should create 1 task file
      JSON_FILES=("$TASKS_PENDING"/*.json)
      [ ${#JSON_FILES[@]} -eq 1 ]
      should_succeed
    }
  }

  context "5. usage error" && {
    it "shows usage when no args" && {
      "$PODMAN_ON_HOST" 2>&1 | grep -q "Usage:"
      should_fail
    }

    it "shows error for unknown command" && {
      "$PODMAN_ON_HOST" badcmd 2>&1 | grep -q "Unknown command:"
      should_fail
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

#!/bin/bash
#
# virtio-net backend selection tests for smolvm.
#
# Covers the part-1 backend-selection plumbing from the user-visible CLI paths.

source "$(dirname "$0")/common.sh"
init_smolvm

log_info "Pre-flight cleanup: killing orphan processes..."
kill_orphan_smolvm_processes

TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'; cleanup_machine" EXIT

echo ""
echo "=========================================="
echo "  smolvm Virtio-Net Tests"
echo "=========================================="
echo ""

test_machine_create_virtio_rejected_until_implemented() {
    cleanup_machine
    local vm_name="virtio-create-test-$$"
    local exit_code=0
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected create failure for unsupported virtio backend"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
    [[ "$output" == *"not ready yet on this branch"* ]] || {
        echo "unexpected output: $output"
        return 1
    }

    local list_output
    list_output=$($SMOLVM machine ls --json 2>&1)
    [[ "$list_output" != *"$vm_name"* ]] || {
        echo "create failure should not persist machine state"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
}

test_machine_run_virtio_rejected_until_implemented() {
    cleanup_machine
    local exit_code=0
    local output

    output=$($SMOLVM machine run --net --net-backend virtio -- true 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected run failure for unsupported virtio backend"
        return 1
    }
    [[ "$output" == *"not ready yet on this branch"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_machine_create_virtio_ports_rejected() {
    cleanup_machine
    local vm_name="virtio-ports-test-$$"
    local exit_code=0
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio -p 18080:80 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected create failure for virtio published port request"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
    [[ "$output" == *"published ports are not supported"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_machine_create_virtio_policy_rejected() {
    cleanup_machine
    local vm_name="virtio-policy-test-$$"
    local exit_code=0
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio --allow-cidr 1.1.1.1/32 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected create failure for virtio policy request"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
    [[ "$output" == *"allow-cidr/allow-host policies are not supported"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_pack_run_virtio_rejected_until_implemented() {
    local output_path="$TEST_DIR/virtio-pack"
    local exit_code=0
    local output

    if [[ ! -f "$output_path.smolmachine" ]]; then
        $SMOLVM pack create --image alpine:latest -o "$output_path" >/dev/null 2>&1 || return 1
    fi

    output=$($SMOLVM pack run --sidecar "$output_path.smolmachine" --net --net-backend virtio -- true 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected pack run failure for unsupported virtio backend"
        return 1
    }
    [[ "$output" == *"not ready yet on this branch"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

run_test "Machine create: virtio rejected until implemented" test_machine_create_virtio_rejected_until_implemented || true
run_test "Machine run: virtio rejected until implemented" test_machine_run_virtio_rejected_until_implemented || true
run_test "Machine create: virtio + published ports rejected" test_machine_create_virtio_ports_rejected || true
run_test "Machine create: virtio + policy rejected" test_machine_create_virtio_policy_rejected || true
run_test "Pack run: virtio rejected until implemented" test_pack_run_virtio_rejected_until_implemented || true

print_summary "Virtio-Net Tests"

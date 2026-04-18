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

test_machine_create_virtio_net_works() {
    cleanup_machine
    local vm_name="virtio-create-test-$$"
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio-net 2>&1) || {
        echo "expected virtio-net machine create to succeed"
        echo "$output"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }

    local list_output
    list_output=$($SMOLVM machine ls --json 2>&1)
    [[ "$list_output" == *"$vm_name"* ]] || {
        echo "virtio-net create should persist machine state"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }

    $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
}

test_machine_run_virtio_net_rejected_until_implemented() {
    cleanup_machine
    local exit_code=0
    local output

    output=$($SMOLVM machine run --net --net-backend virtio-net -- true 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected run failure for unsupported virtio-net backend"
        return 1
    }
    [[ "$output" == *"not ready yet on this branch"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_machine_create_virtio_net_ports_rejected() {
    cleanup_machine
    local vm_name="virtio-ports-test-$$"
    local exit_code=0
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio-net -p 18080:80 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected create failure for virtio-net published port request"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
    [[ "$output" == *"published ports are not supported"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_machine_create_virtio_net_policy_rejected() {
    cleanup_machine
    local vm_name="virtio-policy-test-$$"
    local exit_code=0
    local output

    output=$($SMOLVM machine create "$vm_name" --net --net-backend virtio-net --allow-cidr 1.1.1.1/32 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected create failure for virtio-net policy request"
        $SMOLVM machine delete "$vm_name" -f 2>/dev/null || true
        return 1
    }
    [[ "$output" == *"allow-cidr/allow-host policies are not supported"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

test_pack_run_virtio_net_rejected_until_implemented() {
    local output_path="$TEST_DIR/virtio-pack"
    local exit_code=0
    local output

    if [[ ! -f "$output_path.smolmachine" ]]; then
        $SMOLVM pack create --image alpine:latest -o "$output_path" >/dev/null 2>&1 || return 1
    fi

    output=$($SMOLVM pack run --sidecar "$output_path.smolmachine" --net --net-backend virtio-net -- true 2>&1) || exit_code=$?
    [[ $exit_code -ne 0 ]] || {
        echo "expected pack run failure for unsupported virtio-net backend"
        return 1
    }
    [[ "$output" == *"not ready yet on this branch"* ]] || {
        echo "unexpected output: $output"
        return 1
    }
}

run_test "Machine create: virtio-net works" test_machine_create_virtio_net_works || true
run_test "Machine run: virtio-net rejected until implemented" test_machine_run_virtio_net_rejected_until_implemented || true
run_test "Machine create: virtio-net + published ports rejected" test_machine_create_virtio_net_ports_rejected || true
run_test "Machine create: virtio-net + policy rejected" test_machine_create_virtio_net_policy_rejected || true
run_test "Pack run: virtio-net rejected until implemented" test_pack_run_virtio_net_rejected_until_implemented || true

print_summary "Virtio-Net Tests"

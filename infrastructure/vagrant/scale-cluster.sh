#!/bin/bash
set -e

TARGET_COUNT=$1

if [ -z "$TARGET_COUNT" ]; then
    echo "Usage: $0 <target_node_count>"
    exit 1
fi

echo "📊 Checking current cluster state..."

# Get current running worker nodes
# We look for "knode" in vagrant status
# Output format example:
# knode1                    running (virtualbox)
# knode2                    not created (virtualbox)

CURRENT_NODES=$(vagrant status | grep "knode" | grep -v "not created" | awk '{print $1}')
CURRENT_COUNT=$(echo "$CURRENT_NODES" | grep -c "knode" || true)

echo "   Current worker count: $CURRENT_COUNT"
echo "   Target worker count:  $TARGET_COUNT"

if [ "$TARGET_COUNT" -gt "$CURRENT_COUNT" ]; then
    echo "🚀 Scaling UP to $TARGET_COUNT nodes..."
    WORKER_COUNT=$TARGET_COUNT vagrant up
    
    echo "⏳ Waiting for new nodes to join..."
    sleep 10
    task wait-ready

elif [ "$TARGET_COUNT" -lt "$CURRENT_COUNT" ]; then
    echo "📉 Scaling DOWN to $TARGET_COUNT nodes..."
    
    # Destroy nodes from high to low
    for (( i=$CURRENT_COUNT; i>$TARGET_COUNT; i-- )); do
        NODE="knode$i"
        echo "   💥 Destroying $NODE..."
        
        # Try to drain/delete from Kubernetes first if accessible
        if command -v kubectl &> /dev/null && kubectl get node $NODE &> /dev/null; then
            echo "      Draining and removing from Kubernetes..."
            kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force --timeout=60s || true
            kubectl delete node $NODE || true
        fi
        
        vagrant destroy -f $NODE
    done
    
    echo "✅ Scale down complete."
else
    echo "✅ Node count already matches target ($TARGET_COUNT). Nothing to do."
fi

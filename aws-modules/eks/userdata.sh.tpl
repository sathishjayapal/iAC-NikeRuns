#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_name} \
  --use-max-pods false \
  --kubelet-extra-args '--max-pods=${max_pods_per_node}'

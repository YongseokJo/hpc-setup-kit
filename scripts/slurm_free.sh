#!/usr/bin/env bash
set -euo pipefail

P="${1:-}"

# Nodes with some idle CPUs (works even when no node is fully idle)
mix_dump="$(sinfo -p "${P}" -N -h -o "%N %t %C %e" 2>/dev/null || true)"

# Build list: idle_cores free_mem_MB state node
mix_list="$(
  echo "${mix_dump}" | awk '
    { split($3,c,"/"); idle=c[2]+0; free=$4+0; if (idle>0) printf("%d %d %s %s\n", idle, free, $2, $1) }
  ' | sort -nr
)"

if [[ -z "${mix_list}" ]]; then
  echo "No nodes with idle CPUs found (partition may be fully busy or hidden)."
else
  max_idle="$(echo "${mix_list}" | head -n 1 | awk "{print \$1}")"
  best_node="$(echo "${mix_list}" | head -n 1 | awk "{print \$4}")"
  best_free_mb="$(echo "${mix_list}" | head -n 1 | awk "{print \$2}")"
  best_free_gb="$(awk -v m="${best_free_mb}" 'BEGIN{printf("%d", int(m/1024))}')"

  # conservative suggestions
  safe_cpus=$(( max_idle < 8 ? max_idle : 8 ))
  [[ "${safe_cpus}" -lt 1 ]] && safe_cpus=1
  safe_mem_gb=$(( best_free_gb/2 ))
  [[ "${safe_mem_gb}" -lt 2 ]] && safe_mem_gb=2

  echo "No fully-idle nodes, but idle cores exist (fragmented)."
  echo "Top candidate node: ${best_node} has ~${max_idle} idle cores, ~${best_free_gb}G free mem."
  echo
  echo "Start-now (single-node) suggestion:"
  echo "  sbatch -p ${P} -N 1 --nodelist=${best_node} --ntasks=1 --cpus-per-task=${safe_cpus} --mem=${safe_mem_gb}G your_job.sh"
  echo "  (Remove --nodelist if you prefer scheduler to choose; keep cpus-per-task <= ${max_idle}.)"
  echo

  echo "Top nodes by idle cores (first 10):"
  echo "${mix_list}" | awk '{printf("  idle=%-3d freeMem=%-6dMB state=%-8s node=%s\n",$1,$2,$3,$4)}'
  echo

  # Multi-node uniform chunk: try k=2 and k=4 if possible
  for k in 2 4; do
    have="$(echo "${mix_list}" | awk 'END{print NR}')"
    if [[ "${have}" -ge "${k}" ]]; then
      min_idle="$(echo "${mix_list}" | head -n "${k}" | awk 'NR==1{m=$1} {if($1<m)m=$1} END{print m}')"
      [[ "${min_idle}" -lt 1 ]] && continue
      echo "Start-now (multi-node, uniform chunk) suggestion for k=${k}:"
      echo "  sbatch -p ${P} -N ${k} --ntasks-per-node=${min_idle} --cpus-per-task=1 your_job.sh"
      echo "  (Total tasks = $((k*min_idle)); fits the top ${k} nodes even though they are MIXED.)"
      echo
    fi
  done
fi

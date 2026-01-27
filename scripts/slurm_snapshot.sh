#!/usr/bin/env bash
set -euo pipefail

P="${1:-}"
if [[ -z "${P}" ]]; then
  echo "Usage: $0 <partition> [--user USER] [--top N] [--time HH:MM:SS]"
  echo "Example: $0 gpuA100x4 --user $USER --top 20 --time 00:30:00"
  exit 1
fi

USER_FILTER=""
TOP_N=15
REQ_TIME="00:30:00"   # shorter time limits usually start sooner

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER_FILTER="${2:-}"; shift 2 ;;
    --top)  TOP_N="${2:-15}"; shift 2 ;;
    --time) REQ_TIME="${2:-00:30:00}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 <partition> [--user USER] [--top N] [--time HH:MM:SS]"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 3; }; }
need_cmd sinfo; need_cmd squeue; need_cmd scontrol; need_cmd awk; need_cmd sort; need_cmd uniq; need_cmd head; need_cmd sed; need_cmd wc

ts="$(date -Is)"
cluster="$(scontrol show config 2>/dev/null | awk -F= '/^ClusterName=/{print $2; exit}' | sed 's/^ *//;s/ *$//' || true)"
[[ -z "${cluster}" ]] && cluster="(unknown)"

echo "============================================================"
echo "Slurm Partition Report + Start-Now Hints"
echo "  Time:     ${ts}"
echo "  Cluster:  ${cluster}"
echo "  Partition:${P}"
echo "============================================================"
echo

echo "-------------------- QUEUE STATUS ---------------------------"
if [[ -n "${USER_FILTER}" ]]; then
  SQ_BASE=(squeue -p "${P}" -u "${USER_FILTER}")
  echo "User filter: ${USER_FILTER}"
else
  SQ_BASE=(squeue -p "${P}")
fi

total_jobs="$("${SQ_BASE[@]}" -h -o "%i" | wc -l | awk '{print $1}')"
echo "Total jobs in partition: ${total_jobs}"
echo

echo "Jobs by state:"
"${SQ_BASE[@]}" -h -o "%T" | sort | uniq -c | sort -nr || true
echo

echo "Pending reasons (top ${TOP_N}):"
pend_reasons="$("${SQ_BASE[@]}" -t PD -h -o "%r" | sort | uniq -c | sort -nr | head -n "${TOP_N}" || true)"
echo "${pend_reasons}"
echo

echo "Running jobs (top ${TOP_N}):"
"${SQ_BASE[@]}" -t R -h -o "%.18i %.12u %.8T %.10M %.4D %.20R" | head -n "${TOP_N}" || true
echo

echo "Pending jobs (top ${TOP_N}):"
"${SQ_BASE[@]}" -t PD -h -o "%.18i %.12u %.8T %.12Q %.4D %.30r" | head -n "${TOP_N}" || true
echo

echo "---------------- PARTITION CONFIG (scontrol) ----------------"
scontrol show partition "${P}" || { echo "ERROR: partition '${P}' not found (or no permission)."; exit 4; }
echo

echo "-------------- RESOURCE SUMMARY (sinfo aggregate) ------------"
cpu_line="$(sinfo -p "${P}" -h -o "%C" 2>/dev/null | head -n 1 || true)"
if [[ -n "${cpu_line}" ]]; then
  IFS='/' read -r cpu_alloc cpu_idle cpu_other cpu_total <<< "${cpu_line}"
  echo "CPU summary (Alloc/Idle/Other/Total): ${cpu_alloc}/${cpu_idle}/${cpu_other}/${cpu_total}"
else
  echo "CPU summary: (unavailable)"
fi
echo

echo "------------------ START-NOW RECOMMENDER ---------------------"
echo "Goal: show job shapes that match resources *idle right now*."
echo "Tip: shorter --time and fewer nodes/CPUs usually start sooner."
echo

# Gather idle nodes in partition
# %t node state, %c cpus, %m memMB, %G GRES, %N nodename
idle_dump="$(sinfo -p "${P}" -N -h -o "%t %c %m %G %N" 2>/dev/null || true)"

if [[ -z "${idle_dump}" ]]; then
  echo "Could not read node info via sinfo."
else
  # Consider nodes "idle" if state starts with idle (idle, idle~, idle*, etc)
  idle_only="$(echo "${idle_dump}" | awk '$1 ~ /^idle/ {print}')"
  idle_nodes_count="$(echo "${idle_only}" | awk 'NF>0{c++} END{print c+0}')"

  if [[ "${idle_nodes_count}" -eq 0 ]]; then
    echo "No IDLE nodes detected in partition right now."
    echo "Best you can do is reduce requested resources (nodes/CPUs/GPUs/mem/time) and/or use a different partition."
    echo
  else
    # Compute cpu/mem stats and detect a reasonable per-node shape
    # Also attempt to parse gpu gres: gpu:<type>:<count> or gpu:<count>
    stats="$(
      echo "${idle_only}" | awk '
        function add_gpu(gres,   i, n, tok, a, b, type, cnt) {
          n = split(gres, a, /,/)
          for (i=1; i<=n; i++) {
            tok=a[i]
            sub(/\(.*/, "", tok)
            if (tok ~ /^gpu:/) {
              split(tok, b, /:/)
              if (length(b)==2) { type="gpu"; cnt=b[2] }
              else              { type=b[2]; cnt=b[3] }
              if (cnt ~ /^[0-9]+$/) { gpu_total += cnt; gputype[type] += cnt; gpu_per_node[cnt]++ }
            }
          }
        }
        {
          state=$1; cpus=$2; mem=$3; gres=$4; node=$5
          n++
          cpu_sum += cpus
          mem_sum += mem
          if (n==1 || cpus<cpu_min) cpu_min=cpus
          if (n==1 || cpus>cpu_max) cpu_max=cpus
          if (n==1 || mem<mem_min) mem_min=mem
          if (n==1 || mem>mem_max) mem_max=mem
          cpus_list[n]=cpus
          mem_list[n]=mem
          if (gres!="(null)" && gres!="N/A" && gres!="none" && gres!="UNKNOWN") add_gpu(gres)
        }
        END {
          # median-ish for CPUs and mem: sort lists (simple O(n^2) avoided by printing and using sort externally would be nicer,
          # but awk-only: we approximate with average and min/max).
          cpu_avg = (n>0 ? cpu_sum/n : 0)
          mem_avg = (n>0 ? mem_sum/n : 0)

          printf("N=%d CPU_MIN=%d CPU_AVG=%.1f CPU_MAX=%d MEM_MIN=%d MEM_AVG=%.1f MEM_MAX=%d GPU_TOTAL=%d\n",
                 n, cpu_min, cpu_avg, cpu_max, mem_min, mem_avg, mem_max, gpu_total)

          # print one dominant gpu type if any
          dom_type=""; dom_cnt=0
          for (t in gputype) if (gputype[t] > dom_cnt) { dom_cnt=gputype[t]; dom_type=t }
          if (dom_cnt>0) printf("GPU_DOM_TYPE=%s GPU_DOM_SUM=%d\n", dom_type, dom_cnt)

          # print most common gpu count per node if available
          common_gpu=-1; common_n=0
          for (k in gpu_per_node) if (gpu_per_node[k] > common_n) { common_n=gpu_per_node[k]; common_gpu=k }
          if (common_n>0) printf("GPU_COMMON_PER_NODE=%d GPU_COMMON_NODES=%d\n", common_gpu, common_n)
        }
      '
    )"

    # Parse stats
    eval "$(echo "${stats}" | awk 'NR==1{
      for(i=1;i<=NF;i++){split($i,a,"="); printf("%s=\"%s\"\n",a[1],a[2])}
    }')"

    GPU_DOM_TYPE=""
    GPU_COMMON_PER_NODE=""
    while read -r line; do
      if [[ "${line}" == GPU_DOM_TYPE* ]]; then
        eval "$(echo "${line}" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); printf("%s=\"%s\"\n",a[1],a[2])}}')"
      fi
      if [[ "${line}" == GPU_COMMON_PER_NODE* ]]; then
        eval "$(echo "${line}" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); printf("%s=\"%s\"\n",a[1],a[2])}}')"
      fi
    done < <(echo "${stats}" | tail -n +2)

    echo "Idle nodes right now: ${N}"
    echo "CPUs per idle node (min/avg/max): ${CPU_MIN}/${CPU_AVG}/${CPU_MAX}"
    if [[ "${MEM_MAX}" -gt 0 ]]; then
      # convert MB -> GB roughly
      mem_min_gb="$(awk -v m="${MEM_MIN}" 'BEGIN{printf("%.1f", m/1024.0)}')"
      mem_avg_gb="$(awk -v m="${MEM_AVG}" 'BEGIN{printf("%.1f", m/1024.0)}')"
      mem_max_gb="$(awk -v m="${MEM_MAX}" 'BEGIN{printf("%.1f", m/1024.0)}')"
      echo "Mem per idle node (GB min/avg/max): ${mem_min_gb}/${mem_avg_gb}/${mem_max_gb}"
    else
      echo "Mem per idle node: (unknown/0 reported)"
    fi

    if [[ "${GPU_TOTAL:-0}" -gt 0 ]]; then
      echo "GPUs detected on idle nodes: total=${GPU_TOTAL}, dominant_type=${GPU_DOM_TYPE:-unknown}, common_per_node=${GPU_COMMON_PER_NODE:-unknown}"
    else
      echo "GPUs detected on idle nodes: none (or not reported via %G)."
    fi
    echo

    # Heuristics for "start now":
    # - prefer 1 node
    # - request <= CPU_MIN (safe across all idle nodes)
    # - modest memory request
    # - short time
    #
    # CPU suggestion: take CPU_MIN (most compatible) but cap at something reasonable like 1-8 for interactive quick tests.
    SAFE_CPUS="${CPU_MIN}"
    if [[ "${SAFE_CPUS}" -gt 8 ]]; then SAFE_CPUS=8; fi
    if [[ "${SAFE_CPUS}" -lt 1 ]]; then SAFE_CPUS=1; fi

    # Mem suggestion: if mem_min exists, request 1/4 of mem_min (conservative), else omit.
    MEM_SUGG=""
    if [[ "${MEM_MIN}" -gt 0 ]]; then
      mem_sugg_mb="$(awk -v m="${MEM_MIN}" 'BEGIN{printf("%d", int(m/4))}')"
      # avoid tiny mem; also cap to something like 32G if huge
      mem_sugg_gb="$(awk -v m="${mem_sugg_mb}" 'BEGIN{printf("%d", int(m/1024))}')"
      if [[ "${mem_sugg_gb}" -lt 2 ]]; then mem_sugg_gb=2; fi
      if [[ "${mem_sugg_gb}" -gt 32 ]]; then mem_sugg_gb=32; fi
      MEM_SUGG="--mem=${mem_sugg_gb}G"
    fi

    echo "Recommended 'start-now' sbatch shapes (copy/paste):"
    echo
    echo "1) Single-node CPU job (highest probability):"
    echo "   sbatch -p ${P} -N 1 --ntasks=1 --cpus-per-task=${SAFE_CPUS} ${MEM_SUGG} -t ${REQ_TIME} your_job.sh"
    echo
    if [[ "${N}" -ge 2 ]]; then
      # multi-node conservative: use at most half of currently idle nodes to reduce collision
      use_nodes=$(( N/2 ))
      if [[ "${use_nodes}" -lt 2 ]]; then use_nodes=2; fi
      echo "2) Small multi-node CPU job (only if you truly need it):"
      echo "   sbatch -p ${P} -N ${use_nodes} --ntasks-per-node=1 --cpus-per-task=${SAFE_CPUS} ${MEM_SUGG} -t ${REQ_TIME} your_job.sh"
      echo
    fi

    if [[ "${GPU_TOTAL:-0}" -gt 0 ]]; then
      # Request 1 GPU by default; safer than asking for all 4/8.
      # If common_per_node is known and equals 4, you can suggest 1 or 2.
      GPU_REQ=1
      echo "3) Single-node GPU job (request minimal GPUs to start sooner):"
      echo "   sbatch -p ${P} -N 1 --ntasks=1 --cpus-per-task=${SAFE_CPUS} ${MEM_SUGG} --gres=gpu:${GPU_REQ} -t ${REQ_TIME} your_job.sh"
      echo "   (If your code needs more GPUs, increase slowly: --gres=gpu:2, then :4, etc.)"
      echo
    fi

    echo "If you still pend, the usual culprits are:"
    echo "  - Requesting too many nodes/GPUs (try fewer)"
    echo "  - Too long time limit (try shorter, e.g. --time=00:10:00)"
    echo "  - Mem too high (try smaller --mem)"
    echo "  - QOS/account/constraint mismatch (check scontrol show partition + site docs)"
    echo

    # Quick reminder based on pending reasons observed:
    if echo "${pend_reasons}" | grep -qi "Priority"; then
      echo "Note: many jobs are pending due to Priority — reducing size/time improves chance, but you may still wait."
      echo
    fi
    if echo "${pend_reasons}" | grep -qi "Resources"; then
      echo "Note: many jobs are pending due to Resources — choose a smaller shape (1 node, fewer CPUs/GPUs)."
      echo
    fi
    if echo "${pend_reasons}" | grep -qi "QOS\|Account\|Association"; then
      echo "Note: QOS/Account/Association pending reasons appear — verify -A/--qos settings required by your site."
      echo
    fi
  fi
fi

echo "------------------ OPTIONAL: NODE TABLE ---------------------"
echo "(first ${TOP_N} nodes: state cpus memMB gres name)"
sinfo -p "${P}" -N -h -o "%t %c %m %G %N" 2>/dev/null | head -n "${TOP_N}" || true
echo
echo "Done."

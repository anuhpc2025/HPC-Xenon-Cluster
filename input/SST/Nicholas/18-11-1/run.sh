#!/usr/bin/env python3
import subprocess
import itertools
import re

##############################################################
# HARD-CODED COST MODEL (extracted from cost-model.xlsx)
##############################################################

# Per-core and per-channel costs from spreadsheet
COST = {
    "core_type": {      # per core
        "slow":   30,
        "medium": 48,
        "fast":   96
    },

    # SMT is a multiplier: "yes" = 1.7 × core cost
    "smt_multiplier": {
        "no": 1.0,
        "yes": 1.7
    },

    "l1": {             # per core
        "small": 22,
        "big":   28
    },

    "l2": {             # per core
        "small": 14,
        "big":   20
    },

    "l2org": {          # per core
        "private": 0,
        "shared":  4
    },

    "l3": {             # per core
        "small": 20,
        "big":   36
    },

    "net": {            # per core
        "slow": 6,
        "fast": 16
    },

    # memory: per channel
    "mem_ch_cost": {
        6: 110,
        8: 200
    },

    # memory type has no extra cost (basic vs bw is bandwidth only)
    "mem_type_extra": {
        "basic": 0,
        "bw":    0
    }
}

##############################################################
# DESIGN SPACE (adjust if p1.py lists different values)
##############################################################

core_counts = [32, 64]
core_types  = ["slow", "medium", "fast"]
smt_types   = ["no", "yes"]
l1_types    = ["small", "big"]
l2_types    = ["small", "big"]
l2_orgs     = ["private", "shared"]
l3_types    = ["small", "big"]
net_types   = ["slow", "fast"]
mem_ch     = [6, 8]
mem_types  = ["basic", "bw"]

BUDGET = 9100

##############################################################
# RUN SST & PARSE SIM TIME
##############################################################

def run_sst(cfg):
    cmd = [
        "sst", "p1.py", "--",
        "-e", "beam",
        "-n", str(cfg["n"]),
        "-c", cfg["core_type"],
        "-t", cfg["smt"],
        "-x", cfg["l1"],
        "-y", cfg["l2"],
        "-s", cfg["l2org"],
        "-z", cfg["l3"],
        "-b", cfg["net"],
        "-w", str(cfg["mem_ch"]),
        "-m", cfg["mem_type"]
    ]

    print("RUN:", " ".join(cmd))
    output = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    ).stdout

    # extract:
    # Simulation is complete, simulated time: X.XXXXX ms
    match = re.search(r"simulated time:\s*([0-9.]+)\s*ms", output)
    if not match:
        print(output)
        raise RuntimeError("ERROR: simulated time not found")

    return float(match.group(1))


##############################################################
# COST CALCULATOR
##############################################################

def compute_cost(cfg):
    n = cfg["n"]

    # CORE COST (with SMT multiplier)
    core_base = COST["core_type"][cfg["core_type"]] * n
    core_cost = core_base * COST["smt_multiplier"][cfg["smt"]]

    # L1, L2, L2ORG, L3, NOC → per core
    l1_cost   = COST["l1"][cfg["l1"]]       * n
    l2_cost   = COST["l2"][cfg["l2"]]       * n
    l2o_cost  = COST["l2org"][cfg["l2org"]] * n
    l3_cost   = COST["l3"][cfg["l3"]]       * n
    noc_cost  = COST["net"][cfg["net"]]     * n

    # MEMORY → per channel
    mem_cost  = COST["mem_ch_cost"][cfg["mem_ch"]] * cfg["mem_ch"]

    # memory type (extra cost if any)
    mem_extra = COST["mem_type_extra"][cfg["mem_type"]]

    total = core_cost + l1_cost + l2_cost + l2o_cost + l3_cost + noc_cost + mem_cost + mem_extra
    return total


##############################################################
# MAIN SEARCH
##############################################################

results = []

for (n, ct, smt, l1, l2, l2o, l3, net, mc, mt) in itertools.product(
    core_counts, core_types, smt_types,
    l1_types, l2_types, l2_orgs,
    l3_types, net_types,
    mem_ch, mem_types
):

    cfg = {
        "n": n, "core_type": ct, "smt": smt,
        "l1": l1, "l2": l2, "l2org": l2o,
        "l3": l3, "net": net,
        "mem_ch": mc, "mem_type": mt
    }

    cost = compute_cost(cfg)
    if cost > BUDGET:
        continue

    sim_ms = run_sst(cfg)
    perf = 1.0 / sim_ms

    results.append((sim_ms, perf, cost, cfg))

if not results:
    print("No configs fit within budget!")
    exit()

##############################################################
# CHOOSE BEST CONFIGS
##############################################################

# Best performance = lowest simulated time
best_perf = min(results, key=lambda x: x[0])

# Best performance per dollar
best_per_dollar = max(results, key=lambda x: x[1] / x[2])

##############################################################
# OUTPUT (exact p1.txt line format)
##############################################################

def format_line(sim, cfg):
    return (
        f"{sim}ms,"
        f"{cfg['n']},"
        f"{cfg['core_type']},"
        f"{cfg['smt']},"
        f"{cfg['l1']},"
        f"{cfg['l2']},"
        f"{cfg['l2org']},"
        f"{cfg['l3']},"
        f"{cfg['net']},"
        f"{cfg['mem_ch']},"
        f"{cfg['mem_type']}"
    )

print("\n================ BEST PERFORMANCE ================")
print(format_line(best_perf[0], best_perf[3]))

print("\n========= BEST PERFORMANCE PER DOLLAR ==========")
print(format_line(best_per_dollar[0], best_per_dollar[3]))

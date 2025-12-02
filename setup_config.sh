#!/bin/bash
# Per kernel 6.12.57
set -e

echo "[1/5] Pulizia..."
make mrproper

echo "[2/5] Configurazione Base (x86_64 + KVM)..."
make x86_64_defconfig
make kvm_guest.config


echo "[3/5] Forzatura BPF, XDP e BTF (Override)..."

# --- CORE BPF ---
./scripts/config --enable CONFIG_BPF
./scripts/config --enable CONFIG_BPF_SYSCALL
./scripts/config --enable CONFIG_BPF_JIT
./scripts/config --enable CONFIG_BPF_JIT_DEFAULT_ON
./scripts/config --enable CONFIG_BPF_LSM
./scripts/config --enable CONFIG_NETFILTER_BPF_LINK
./scripts/config --enable CONFIG_NET_SOCK_MSG
./scripts/config --enable CONFIG_PAGE_POOL
./scripts/config --enable CONFIG_BPF_EVENTS

# --- NETWORKING XDP ---
./scripts/config --enable CONFIG_XDP_SOCKETS
./scripts/config --enable CONFIG_XDP_SOCKETS_DIAG
./scripts/config --enable CONFIG_NET_CLS_BPF
./scripts/config --enable CONFIG_NET_ACT_BPF

# --- DEBUG & BTF ---
# Importante: Disabilitiamo REDUCED prima di abilitare BTF
./scripts/config --enable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_DEBUG_INFO_NONE
./scripts/config --disable CONFIG_DEBUG_INFO_REDUCED
./scripts/config --enable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --enable CONFIG_DEBUG_INFO_BTF
./scripts/config --enable CONFIG_DEBUG_INFO_BTF_MODULES
./scripts/config --enable CONFIG_GDB_SCRIPTS
./scripts/config --enable CONFIG_IKHEADERS

# Disabilitiamo KASLR per facilitare il debug
./scripts/config --disable CONFIG_RANDOMIZE_BASE
./scripts/config --disable CONFIG_RANDOMIZE_MEMORY

# Altro per Syzkaller
./scripts/config --enable CONFIG_CONFIGFS_FS

#Tracepoints
./scripts/config --enable CONFIG_HAVE_SYSCALL_TRACEPOINTS
./scripts/config --enable CONFIG_FTRACE_SYSCALLS

./scripts/config --enable CONFIG_TRACEPOINTS
./scripts/config --enable CONFIG_FTRACE
./scripts/config --enable CONFIG_FUNCTION_TRACER
./scripts/config --enable CONFIG_FUNCTION_GRAPH_TRACER
./scripts/config --enable CONFIG_IRQSOFF_TRACER
./scripts/config --enable CONFIG_PREEMPT_TRACER
./scripts/config --enable CONFIG_SCHED_TRACER
./scripts/config --enable CONFIG_STACK_TRACER
./scripts/config --enable CONFIG_STACKTRACE_BUILD_ID
./scripts/config --enable CONFIG_TRACER_SNAPSHOT
./scripts/config --enable CONFIG_HWLAT_TRACER
./scripts/config --enable CONFIG_OSNOISE_TRACER
./scripts/config --enable CONFIG_TIMERLAT_TRACER
./scripts/config --enable CONFIG_TRACE_EVENT_INJECT
./scripts/config --enable CONFIG_MMIOTRACE
./scripts/config --enable CONFIG_MMIOTRACE_TEST


echo "[4/5] Calcolo dipendenze finali..."
# Qui il kernel ricalcola tutto. Se le dipendenze sono ok, BTF resta.
yes "" | make olddefconfig

echo "[5/5] Verifica Configurazione..."
if grep -q "CONFIG_DEBUG_INFO_BTF=y" .config; then
    echo "✅ CONFIG_DEBUG_INFO_BTF è ATTIVO. Puoi compilare."
    echo "   Esegui: make -j$(nproc)"
else
    echo "❌ ERRORE: CONFIG_DEBUG_INFO_BTF risulta ancora disattivato!"
    echo "   Controlla se pahole è visto correttamente o se mancano dipendenze."
    # Controllo debug per capire perché è saltato
    echo "   Stato DEBUG_INFO:"
    grep "CONFIG_DEBUG_INFO" .config
    exit 1
fi

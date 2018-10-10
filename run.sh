for T in {4..100..1}; do
    rm ./main-$T 2> /dev/null
    nasm -felf64 -DRS=$T -DADD main.asm
    ld main.o -o main-$T
    echo -n "$T "
    res="$(taskset -c 1 perf stat -r 5 -e cycles:u,instructions:u,cpu/event=0xA2,umask=0x4,name=RESOURCE_STALLS.RS/u,cpu/event=0xA2,umask=0x1,name=RESOURCE_STALLS.ANY/u,cpu/event=0xA2,umask=0x10,name=RESOURCE_STALLS.ROB/u,cpu/event=0x9C,umask=0x1,inv=1,cmask=1,name=IDQ_UOPS_NOT_DELIVERED.CYCLES_FE_WAS_OK/u,cpu/event=0xE,umask=0x1,inv=1,cmask=1,name=UOPS_ISSUED.STALL_CYCLES/u,cpu/event=0x79,umask=0x4,cmask=1,name=IDQ.MITE_CYCLES/u,cpu/event=0x5E,umask=0x1,name=RS_EVENTS.EMPTY_CYCLES/u,cpu/event=0x79,umask=0x8,cmask=1,name=IDQ.DSB_CYCLES/u '-x ' ./main-$T 2>&1 > /dev/null)"
    echo $res | cut '-d ' -f1,6,11,16,21,26,31,36,41,46,51,56
done

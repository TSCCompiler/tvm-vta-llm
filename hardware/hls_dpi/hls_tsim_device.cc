//
// Created by sunhh on 24-4-2.
//

#include "vta/hls_dpi/hls_tsim_device.h"

#include <verilated_vcd_c.h>


#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

// Override Verilator finish definition
// VL_USER_FINISH needs to be defined when compiling Verilator code
void vl_finish(const char* filename, int linenum, const char* hier) {
    Verilated::gotFinish(true);
}
int VTADPIEval(int nstep){
    uint64_t trace_count = 0;
    Verilated::flushCall();
    Verilated::gotFinish(false);

    uint64_t start = 0;

    VL_TSIM_NAME* top = new VL_TSIM_NAME;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;

    top->trace(tfp, 99);
    tfp->open(STRINGIZE_VALUE_OF(TSIM_TRACE_FILE));

    for (int i = 0; i < 10; ++i) {
        top->reset = 1;
        top->clock = 0;
        top->eval();
        if (trace_count >= start)
            tfp->dump(static_cast<vluint64_t>(trace_count*2));
        top->clock = 1;
        top->eval();
        if (trace_count >= start)
            tfp->dump(static_cast<vluint64_t>(trace_count * 2 + 1));
        trace_count++;
    }
    top->reset = 0;
    top->io_queue_ready = 1;

    for (int i = 0; i < nstep; ++i) {
        top->clock = 0;
        top->eval();
        tfp->dump(static_cast<vluint64_t>(trace_count * 2));
        top->clock = 1;
        top->eval();
        tfp->dump(static_cast<vluint64_t>(trace_count * 2 + 1));

        trace_count++;
    }
    tfp->close();
    uint32_t wd = top->io_queue_bits[0];

    delete top;

    return wd;

}
//
// Created by sunhh on 24-4-2.
//

#include "vta/hls_dpi/hls_tsim_device.h"
#include "vta/dpi/tsim.h"

#include <verilated_vcd_c.h>

#include "VTestTopWithCHLS.h"


#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

static VTAContextHandle _ctx = nullptr;
static VTAAxisDPIFunc _axis_dpi_func = nullptr;

void VTAAxisDPI(const svOpenArrayHandle rd_bits,
                dpi8_t rd_valid,
                dpi8_t* rd_ready)
{
    assert(rd_bits != NULL);
    assert(svSize(rd_bits, 1) == 2);
    assert(svDimensions(rd_bits) == 1);

    assert(svSize(rd_bits, 0) == 64);
    if (_ctx){
        if (_axis_dpi_func){
            _axis_dpi_func(_ctx, rd_bits, rd_valid, rd_ready);
        }
    }
//    assert(rd_bits != NULL);
//    assert(svDimensions(rd_bits) == 1);
//    assert(svSize(rd_bits, 1) <= 8);
//    assert(svSize(rd_bits, 0) == 64);
//    int lftIdx = svLeft(rd_bits, 1);
//    int rgtIdx = svRight(rd_bits, 1);
//    int blkNb  = lftIdx - rgtIdx + 1;
//    for (int i = 0; i < blkNb; ++i) {
//        uint64_t* elemPtr = (uint64_t*)svGetArrElemPtr1(rd_bits, rgtIdx + i);
//        assert(elemPtr != NULL);
//        auto value = elemPtr[0];
//        fprintf(stdout, "value : %ld\n", value);
//    }
//    rd_ready[0] = 1;


}
// Override Verilator finish definition
// VL_USER_FINISH needs to be defined when compiling Verilator code
void vl_finish(const char* filename, int linenum, const char* hier) {
    Verilated::gotFinish(true);
}
void VTAHLSDPIInit(VTAContextHandle ctx,
                   VTAAxisDPIFunc axisDpiFunc){
    _ctx = ctx;
    _axis_dpi_func = axisDpiFunc;
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
    uint32_t cnt = top->io_recv_cnt;
    fprintf(stdout, "recv cnt : %d\n", cnt);

    delete top;

    return wd;

}
//
// Created by sunhh on 24-4-2.
//

#include "vta/hls_dpi/hls_tsim_device.h"
#include "vta/dpi/tsim.h"

#include <verilated_vcd_c.h>

//#include "VTestTopWithCHLS.h"
//#include "VHostSimAxiliteModule.h"
#include <VDPISimFetchModule.h>


#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

static VTAContextHandle _ctx = nullptr;
static VTAAxisDPIFunc _axis_dpi_func = nullptr;
static VTAHostDPIFunc _host_dpi = nullptr;
static VTAMemDPIFunc _mem_dpi = nullptr;

void VTAAxisDPI(dpi32_t user_id,
        const svOpenArrayHandle rd_bits,
                dpi8_t rd_valid,
                dpi8_t* rd_ready)
{
    if (_ctx){
        if (_axis_dpi_func){
            _axis_dpi_func(_ctx, user_id, rd_bits, rd_valid, rd_ready);
        }
    }

}

void VTAHostDPI(dpi8_t* req_valid,
                dpi8_t* req_opcode,
                dpi8_t* req_addr,
                dpi32_t* req_value,
                dpi8_t req_deq,
                dpi8_t resp_valid,
                dpi32_t resp_value) {
    assert(_host_dpi != nullptr);
    (*_host_dpi)(_ctx, req_valid, req_opcode,
                 req_addr, req_value, req_deq,
                 resp_valid, resp_value);
}

void VTAMemDPI(dpi8_t rd_req_valid,
               dpi8_t rd_req_len,
               dpi8_t rd_req_id,
               dpi64_t rd_req_addr,
               dpi8_t wr_req_valid,
               dpi8_t wr_req_len,
               dpi64_t wr_req_addr,
               dpi8_t wr_valid,
               const svOpenArrayHandle wr_value,
               dpi64_t wr_strb,
               dpi8_t* rd_valid,
               dpi8_t* rd_id,
               const svOpenArrayHandle  rd_value,
               dpi8_t rd_ready) {
    assert(_mem_dpi != nullptr);
    (*_mem_dpi)(_ctx, rd_req_valid, rd_req_len, rd_req_id,
                rd_req_addr, wr_req_valid, wr_req_len, wr_req_addr,
                wr_valid, wr_value, wr_strb,
                rd_valid, rd_id,rd_value, rd_ready);

}
// Override Verilator finish definition
// VL_USER_FINISH needs to be defined when compiling Verilator code
void vl_finish(const char* filename, int linenum, const char* hier) {
    Verilated::gotFinish(true);
}
void VTAHLSDPIInit(VTAContextHandle ctx,
                   VTAAxisDPIFunc axisDpiFunc,
                   VTAHostDPIFunc host_dpi,
                   VTAMemDPIFunc mem_dpi){
    _ctx = ctx;
    _axis_dpi_func = axisDpiFunc;
    _host_dpi = host_dpi;
    _mem_dpi = mem_dpi;
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
//    tfp->open("/mnt/workspace/project/nn_compiler/vta-hw/hardware/chisel/test_run_dir/AxiliteExampleHls/axilite.vcd");
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
//    top->io_queue_ready = 1;

    while (!Verilated::gotFinish()){
        top->clock = 0;
        top->eval();
        tfp->dump(static_cast<vluint64_t>(trace_count * 2));
        top->clock = 1;
        top->eval();
        tfp->dump(static_cast<vluint64_t>(trace_count * 2 + 1));
        trace_count++;
    }

//    for (int i = 0; i < nstep; ++i) {
//        top->clock = 0;
//        top->eval();
//        tfp->dump(static_cast<vluint64_t>(trace_count * 2));
//        top->clock = 1;
//        top->eval();
//        tfp->dump(static_cast<vluint64_t>(trace_count * 2 + 1));
//
//        trace_count++;
//    }
    tfp->close();
//    uint32_t wd = top->io_queue_bits[0];
//    uint32_t cnt = top->io_recv_cnt;
    bool interrupt = top->io_interrupt;
    fprintf(stdout, "interrupt : %d\n", interrupt);

    delete top;

    return interrupt;

}
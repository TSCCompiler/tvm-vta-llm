//
// Created by sunhh on 2022/12/22.
//
#include <iostream>

#include "TOP.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

struct VerilatedContextHandle{
    VerilatedVcdC* tfp = nullptr;
    TOP         *  top = nullptr;
};

int main(int argc, char** argv){
    auto * context = new VerilatedContextHandle;
    TOP* top = new TOP;
    context->top = top;
    context->tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    top->trace(context->tfp, 0);
    context->tfp->open("./wave.vcd");

    top->clock = 0;
    top->reset = 1;

    vluint64_t main_time = 0;

    while (!Verilated::gotFinish() && main_time < static_cast<vluint64_t>(2*10)){
        if ((main_time % 10) == 1){
            top->clock = 1;
        }
        if ((main_time % 10) == 6) {
            top->reset = 0;
        }
        top->eval();
        context->tfp->dump(main_time);
        main_time++;
    }
    top->io_a = -3;
    top->io_b = 2;
    top->io_c = 10;
    vluint64_t local_time = 0;
    top->clock = 0;
    while (!Verilated::gotFinish() && local_time < static_cast<vluint64_t>(1*10)){
        if ((main_time % 10) == 1){
            top->clock = 1;
        }
        if ((main_time %  10) == 6){
            top->clock = 0;
        }
        top->eval();
        context->tfp->dump(main_time);
        main_time++;
        local_time++;
    }

    int ret = top->io_y;
    std::cout << "ret is " << ret << "\n";
    return  0;

}
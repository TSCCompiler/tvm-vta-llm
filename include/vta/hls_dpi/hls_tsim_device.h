//
// Created by sunhh on 24-4-2.
//

#ifndef VTA_HW_HLS_TSIM_DEVICE_H
#define VTA_HW_HLS_TSIM_DEVICE_H

#include <tvm/runtime/c_runtime_api.h>
#include <stdint.h>
#include <svdpi.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char dpi8_t;

typedef unsigned int dpi32_t;

typedef unsigned long long dpi64_t; // NOLINT(*)

TVM_DLL int VTADPIEval(int nstep);

#ifdef __cplusplus
}
#endif

#endif //VTA_HW_HLS_TSIM_DEVICE_H

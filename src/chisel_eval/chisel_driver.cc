//
// Created by sunhh on 2024/4/20.
//
#include <tvm/runtime/registry.h>
#include <vta/driver.h>
#include "../vmem/virtual_memory.h"
#include "vta/chisel_eval/chisel_driver.h"


namespace vta{
namespace chisel {



}
}

void* VTAMemAlloc(size_t size, int cached) {
    return vta::vmem::VirtualMemoryManager::Global()->Alloc(size);
}

void VTAMemFree(void* buf) {
    vta::vmem::VirtualMemoryManager::Global()->Free(buf);
}

vta_phy_addr_t VTAMemGetPhyAddr(void* buf) {
    return vta::vmem::VirtualMemoryManager::Global()->GetPhyAddr(buf);
}
void VTAMemCopyFromHost(void* dst, const void* src, size_t size) {
    memcpy(dst, src, size);
}
void VTAMemCopyToHost(void* dst, const void* src, size_t size) {
    memcpy(dst, src, size);
}
void VTAFlushCache(void* vir_addr, vta_phy_addr_t phy_addr, int size) {
}
void VTAInvalidateCache(void* vir_addr, vta_phy_addr_t phy_addr, int size) {
}

VTADeviceHandle VTADeviceAlloc() {
    //todo add implement later
    LOG(FATAL) << "VTADevice for chisel is not implemented yet";
    return nullptr;
}
void VTADeviceFree(VTADeviceHandle handle) {
    //todo add implement later
    LOG(FATAL) << "VTADeviceFree for chisel is not implemented yet";
//    delete static_cast<vta::tsim::Device*>(handle);
}
int VTADeviceRun(VTADeviceHandle handle,
                 vta_phy_addr_t insn_phy_addr,
                 uint32_t insn_count,
                 uint32_t wait_cycles) {
    //todo add implement later
    LOG(FATAL) << "VTADeviceRun is not implemented yet";
    return -1;
//    return static_cast<vta::tsim::Device*>(handle)->Run(
//            insn_phy_addr,
//            insn_count,
//            wait_cycles);
}

vta_phy_addr_t VTAGetPhyAddrFromHandle(void *handle) {
    return 0;
}

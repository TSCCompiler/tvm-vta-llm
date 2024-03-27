<!--- Licensed to the Apache Software Foundation (ASF) under one -->
<!--- or more contributor license agreements.  See the NOTICE file -->
<!--- distributed with this work for additional information -->
<!--- regarding copyright ownership.  The ASF licenses this file -->
<!--- to you under the Apache License, Version 2.0 (the -->
<!--- "License"); you may not use this file except in compliance -->
<!--- with the License.  You may obtain a copy of the License at -->

<!---   http://www.apache.org/licenses/LICENSE-2.0 -->

<!--- Unless required by applicable law or agreed to in writing, -->
<!--- software distributed under the License is distributed on an -->
<!--- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY -->
<!--- KIND, either express or implied.  See the License for the -->
<!--- specific language governing permissions and limitations -->
<!--- under the License. -->

VTA-LLM Hardware Design Stack
=========================
[![Build Status](https://ci.tlcpack.ai/job/tvm-vta/job/main/badge/icon)](https://ci.tlcpack.ai/job/tvm-vta/job/main/)

VTA-LLM 

还在开发中。。。。。。

希望增加softmax等新的op，让tvm-vta支持transformer模型的推理，现在通过增加了一个reduce的计算引擎，实现了softmax算子。
相关代码在vta/python/vta_softmax.py里面。目前仅把新的算子增加到vta_fsim的 软件仿真模块里，并通过了测试。
下一步将会把相关算法添加到chisel的rtl里面，或者增加到hls里面。下一步还想通过blackbox的方式，把hls生成的
verilog加入到chisel的rtl里面，并通过verilator进行仿真，最后实现在xilinx fpga上的部署。
  
VTA(versatile tensor accelerator) is an open-source deep learning accelerator complemented with an end-to-end TVM-based compiler stack.

The key features of VTA include:

- Generic, modular, open-source hardware
  - Streamlined workflow to deploy to FPGAs.
  - Simulator support to prototype compilation passes on regular workstations.
- Driver and JIT runtime for both simulator and FPGA hardware back-end.
- End-to-end TVM stack integration
  - Direct optimization and deployment of models from deep learning frameworks via TVM.
  - Customized and extensible TVM compiler back-end.
  - Flexible RPC support to ease deployment, and program FPGAs with the convenience of Python.
- Running on xilinx pynq
  ```shell
  su root
  source /home/xilinx/.bashrc
  python3 -m vta.exec.rpc_server --host 192.168.6.200 --port 9091 
  ```
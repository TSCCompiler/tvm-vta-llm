# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
"""
.. _vta-get-started:

Get Started with VTA
====================
**Author**: `Thierry Moreau <https://homes.cs.washington.edu/~moreau/>`_

This is an introduction tutorial on how to use TVM to program the VTA design.

In this tutorial, we will demonstrate the basic TVM workflow to implement
a vector addition on the VTA design's vector ALU.
This process includes specific scheduling transformations necessary to lower
computation down to low-level accelerator operations.

To begin, we need to import TVM which is our deep learning optimizing compiler.
We also need to import the VTA python package which contains VTA specific
extensions for TVM to target the VTA design.
"""
from __future__ import absolute_import, print_function

import os

os.environ[
    "PATH"] = "D:\\workspace\\project\\nn_compiler\\tvm\\cmake-build-release_mingw;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\bin\\amd64;D:\\Halide\llvm-install-rel\\bin;" \
              "C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\v11.0\\bin;" + os.environ["PATH"]
# print(os.environ["PATH"])
import tvm
import tvm.relay
from tvm import te
import vta
import numpy as np

######################################################################
# Loading in VTA Parameters
# ~~~~~~~~~~~~~~~~~~~~~~~~~
# VTA is a modular and customizable design. Consequently, the user
# is free to modify high-level hardware parameters that affect
# the hardware design layout.
# These parameters are specified in the :code:`vta_config.json` file by their
# :code:`log2` values.
# These VTA parameters can be loaded with the :code:`vta.get_env`
# function.
#
# Finally, the TVM target is also specified in the :code:`vta_config.json` file.
# When set to *sim*, execution will take place inside of a behavioral
# VTA simulator.
# If you want to run this tutorial on the Pynq FPGA development platform,
# follow the *VTA Pynq-Based Testing Setup* guide.

env = vta.get_env()

######################################################################
# FPGA Programming
# ----------------
# When targeting the Pynq FPGA development board, we need to configure
# the board with a VTA bitstream.

# We'll need the TVM RPC module and the VTA simulator module
from tvm import rpc
import tvm._ffi
from tvm.runtime.module import _ffi_api
from tvm.contrib import utils
from vta.testing import simulator
from vta.testing.simulator import load_module_with_lib, load_module_sim
from vta.libinfo import find_libvta


# We read the Pynq RPC host IP address and port number from the OS environment
host = os.environ.get("VTA_RPC_HOST", "192.168.6.200")
port = int(os.environ.get("VTA_RPC_PORT", "9091"))

# We configure both the bitstream and the runtime system on the Pynq
# to match the VTA configuration specified by the vta_config.json file.
if env.TARGET == "pynq" or env.TARGET == "de10nano":

    # Make sure that TVM was compiled with RPC=1
    assert tvm.runtime.enabled("rpc")
    remote = rpc.connect(host, port)

    # Reconfigure the JIT runtime
    # vta.reconfig_runtime(remote)

    # Program the FPGA with a pre-compiled VTA bitstream.
    # You can program the FPGA with your own custom bitstream
    # by passing the path to the bitstream file instead of None.
    vta.program_fpga(remote, bitstream="/home/share/data/workspace/project/fpga/hls/vta-hw/build/vta.bit")

# In simulation mode, host the RPC server locally.
elif env.TARGET in ("sim", "tsim", "intelfocl"):
    remote = rpc.LocalSession()

    @tvm._ffi.register_func("tvm.rpc.server.load_module", override=True)
    def load_module(file_name):
        return load_module_sim(file_name)

    if env.TARGET in ["intelfocl"]:
        # program intelfocl aocx
        vta.program_fpga(remote, bitstream="vta.bitstream")

b = 1
m = 4
vocab_size = 1024
v = vocab_size // 16

k1 = te.reduce_axis((0, v), name="k")
k2 = te.reduce_axis((0, 16), name="ik")

A = te.placeholder((b, m, v, 16), name='A', dtype=env.acc_dtype)
A_buf = te.compute((b, m, v, 16), lambda *indices: A(*indices), "A_buf")
C_buf = te.compute(
    (b, m),
    lambda *i: te.max(A_buf(*i, k1, k2), axis=[k1, k2])
)

C_buf_pad = te.compute((b, m, 16), lambda bi, mi, pi: C_buf(bi, mi), "C_buf_pad")
C = te.compute((b, m, 16), lambda *i : C_buf_pad(*i), name="C")

s = te.create_schedule(C.op)

print(tvm.lower(s, [A, C], simple_mode=True))

s[A_buf].set_scope("local.acc_buffer")
s[C_buf].set_scope("local.acc_buffer")
s[C_buf_pad].set_scope("local.acc_buffer")
print(s[C_buf].op.axis)
cb_b, cb_m = s[C_buf].op.axis
cbp_b, cbp_m, _ = s[C_buf_pad].op.axis
s[C_buf].compute_at(s[C_buf_pad], cbp_m)

s[A_buf].pragma(s[A_buf].op.axis[0], "dma_copy")

s[C].pragma(s[C].op.axis[0], "dma_copy")
s[C_buf].pragma(C_buf.op.axis[0], "alu")

print(tvm.lower(s, [A, C], simple_mode=True))

# Let's take a look at the finalized schedule
# print(vta.lower(s, [A, C], simple_mode=True))

# my_vmax = vta.build(
#     s, [A, C], tvm.target.Target("ext_dev", host="llvm")
# )
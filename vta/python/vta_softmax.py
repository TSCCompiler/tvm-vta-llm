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
import vta.build_module

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
from my_vta_pipeline import my_build_config

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
ob = b // env.BATCH
m = 4
vocab_size = 1024
v = vocab_size // 16

k1 = te.reduce_axis((0, v), name="k")
k2 = te.reduce_axis((0, 16), name="ik")

k3 = te.reduce_axis((0, v), name="k")
k4 = te.reduce_axis((0, 16), name="ik")

A = te.placeholder((ob, m, v, env.BATCH, env.BLOCK_OUT), name='A', dtype=env.acc_dtype)
A_buf = te.compute((ob, m, v, env.BATCH, env.BLOCK_OUT), lambda *indices: A(*indices), "A_buf")
C_buf = te.compute(
    (ob, m, env.BATCH, env.BLOCK_OUT),
    lambda obi, mi, bi, ti: te.max(A_buf(obi, mi, k1, bi, k2), axis=[k1, k2]), "C_buf"
)
Exp_buf = te.compute((ob, m, v, env.BATCH, env.BLOCK_OUT),
                     lambda obi, mi, vi, bi, tnsi: A_buf(obi, mi, vi, bi, tnsi) - C_buf(obi, mi, bi, tnsi),
                     "Exp_buf")

Exp_buf_sum = te.compute((ob, m, env.BATCH, env.BLOCK_OUT),
                         lambda obi, mi, bi, ti: te.sum(Exp_buf(obi, mi, k3, bi, k4), axis=[k3, k4]))

Soft_max = te.compute((ob, m, v, env.BATCH, env.BLOCK_OUT),
                      lambda obi, mi, vi, bi, ti: Exp_buf(obi, mi, vi, bi, ti) // Exp_buf_sum(obi, mi, bi, ti))

C = te.compute((ob, m, v, env.BATCH, env.BLOCK_OUT), lambda *i: Soft_max(*i).astype(env.inp_dtype), "C")
# C = te.compute((ob, m, env.BATCH, env.BLOCK_OUT), lambda *i: Exp_buf_sum(*i).astype(env.inp_dtype), "C")

s = te.create_schedule(C.op)

print(tvm.lower(s, [A, C], simple_mode=True))
llvm_module = tvm.build(s, [A, C], tvm.target.Target("llvm", host=env.target_host))


s[A_buf].compute_at(s[C], s[C].op.axis[1])
s[C_buf].compute_at(s[C], s[C].op.axis[1])
s[Exp_buf].compute_at(s[C], s[C].op.axis[1])
s[Exp_buf_sum].compute_at(s[C], s[C].op.axis[1])
s[Soft_max].compute_at(s[C], s[C].op.axis[1])

cb_b, cb_m, cb_bi, cb_ti = s[C_buf].op.axis

s[C_buf].reorder(cb_m, k1, cb_b, cb_bi, k2, cb_ti)
s[C_buf].tensorize(cb_bi, env.aluc)


s[A_buf].set_scope("local.acc_buffer")
s[C_buf].set_scope("local.acc_buffer")
s[Exp_buf].set_scope("local.acc_buffer")
s[Exp_buf_sum].set_scope("local.acc_buffer")
s[Soft_max].set_scope("local.acc_buffer")


sum_ob, sum_m, sum_bi, sum_ti = s[Exp_buf_sum].op.axis
s[Exp_buf_sum].reorder(k3, sum_ob, sum_m, sum_bi, k4, sum_ti)
s[Exp_buf_sum].tensorize(sum_bi, env.pool_sum)

s[Exp_buf].pragma(Exp_buf.op.axis[0], "alu")

s[A_buf].pragma(s[A_buf].op.axis[0], "dma_copy")
s[C].pragma(s[C].op.axis[2], "dma_copy")

s[Soft_max].pragma(Soft_max.op.axis[0], "alu")



print(vta.lower(s, [A, C], simple_mode=True))

my_softmax = vta.build(s, [A, C],
                       tvm.target.Target("ext_dev", host=env.target_host))

temp = "./"
my_softmax.save(os.path.join(temp, "softmax.o"))

remote.upload(os.path.join(temp, "softmax.o"))

f = remote.load_module(os.path.join(temp, "softmax.o"))

env = vta.get_env()

ctx = remote.ext_dev(0)

dev = tvm.device('cpu', 0)

A_orig = np.random.randint(-128, 128, size=(ob, m, v, env.BATCH, env.BLOCK_OUT)).astype(A.dtype)

A_nd = tvm.nd.array(A_orig, ctx)
C_nd = tvm.nd.array(np.zeros((ob, m, v, env.BATCH, env.BLOCK_OUT)).astype(C.dtype), ctx)
Aref_nd = tvm.nd.array(A_orig, dev)
Cref_nd = tvm.nd.array(np.zeros((ob, m, v, env.BATCH, env.BLOCK_OUT)).astype(C.dtype), dev)

if env.TARGET in ["sim", "tsim"]:
    simulator.clear_stats()

f(A_nd, C_nd)

print('begin to infer with cpu')
llvm_module(Aref_nd, Cref_nd)

np.testing.assert_equal(Cref_nd.numpy(), C_nd.numpy())
# Print stats
if env.TARGET in ["sim", "tsim"]:
    sim_stats = simulator.stats()
    print("Execution statistics:")
    for k, v in sim_stats.items():
        print("\t{:<16}: {:>16}".format(k, v))

print('finish compute')

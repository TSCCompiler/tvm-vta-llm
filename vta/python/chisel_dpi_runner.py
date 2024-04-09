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
from __future__ import absolute_import, print_function

import os

import tvm
import tvm.relay
from tvm import te
import vta
import numpy as np
import vta.build_module
from vta.libinfo import find_libvta

env = vta.get_env()

from vta.testing import simulator

if __name__ == '__main__':
    if env.TARGET == "chisel":
        lib_hw = find_libvta("libhls_tsim_device", optional=True)
        assert lib_hw
        dpi_module = tvm.runtime.load_module(lib_hw[0], "vta-chisel-tsim")
        print(dpi_module)
        eval_fn = dpi_module["Eval"]
        get_data_fn = dpi_module["GetArray"]
        ret = eval_fn(10)
        ret_arr = get_data_fn(15)
        print(ret_arr)
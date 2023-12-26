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
"""Utilities to start simulator."""
import os
import ctypes
import json
import warnings
import tvm
import tvm._ffi
from ..environment import get_env
from ..libinfo import find_libvta
from tvm.runtime.module import _ffi_api


def load_module_with_lib(path, fmt="", extlib=[]):
    """Load module from file.

    Parameters
    ----------
    path : str
        The path to the module file.

    fmt : str, optional
        The format of the file, if not specified
        it will be inferred from suffix of the file.

    Returns
    -------
    module : runtime.Module
        The loaded module

    Note
    ----
    This function will automatically call
    cc.create_shared if the path is in format .o or .tar
    """
    if os.path.isfile(path):
        path = os.path.realpath(path)
    else:
        raise ValueError("cannot find file %s" % path)

    # n_options = []
    # for opt in extlib:
    #     n_options.append("l"+opt)
    n_options = ["-l" + opt for opt in extlib]

    # High level handling for .o and .tar file.
    # We support this to be consistent with RPC module load.
    if path.endswith(".o"):
        # Extra dependencies during runtime.
        from tvm.contrib import cc as _cc

        _cc.create_shared(path + ".so", path, options=n_options)
        path += ".so"
    elif path.endswith(".tar"):
        # Extra dependencies during runtime.
        from tvm.contrib import cc as _cc, utils as _utils, tar as _tar

        tar_temp = _utils.tempdir(custom_path=path.replace(".tar", ""))
        _tar.untar(path, tar_temp.temp_dir)
        files = [tar_temp.relpath(x) for x in tar_temp.listdir()]
        _cc.create_shared(path + ".so", files, options=n_options)
        path += ".so"
    # Redirect to the load API
    return _ffi_api.ModuleLoadFromFile(path, fmt)


def load_module_sim(file_name):
    env = get_env()
    require_sim = env.TARGET in ("sim", "tsim")

    lib_driver_name = (
        "libvta_tsim"
        if env.TARGET == "tsim"
        else "libvta"
        if env.TARGET == "intelfocl"
        else "libvta_fsim"
    )
    # args = str(file_name).split(';')
    file_name = str(file_name)
    ext_lib = []
    # lib_driver = ""
    if os.name == 'nt':
        lib_driver = find_libvta(lib_driver_name, optional=(not require_sim))
        lib_driver = lib_driver[0] + ".a.lib"
        ext_lib.append(lib_driver)

    """Load module from remote side."""
    path = file_name
    m = load_module_with_lib(path, extlib=ext_lib)
    # logger.info("load_module %s", path)
    return m


def _load_sw():
    """Load hardware library for simulator."""

    env = get_env()
    lib_driver_name = (
        "libvta_tsim"
        if env.TARGET == "tsim"
        else "libvta"
        if env.TARGET == "intelfocl"
        else "libvta_fsim"
    )
    require_sim = env.TARGET in ("sim", "tsim")
    libs = []

    # Load driver library
    lib_driver = find_libvta(lib_driver_name, optional=(not require_sim))

    if not lib_driver:
        return []

    try:
        libs = [ctypes.CDLL(lib_driver[0], ctypes.RTLD_GLOBAL)]
    except OSError as err:
        if require_sim:
            raise err
        warnings.warn("Error when loading VTA driver {}: {}".format(lib_driver[0], err))
        return []

    # if os.name == 'nt':
    #     @tvm._ffi.register_func("tvm.rpc.server.load_module", override=True)
    #     def load_module(file_name):
    #         env = get_env()
    #         require_sim = env.TARGET in ("sim", "tsim")
    #
    #         lib_driver_name = (
    #             "libvta_tsim"
    #             if env.TARGET == "tsim"
    #             else "libvta"
    #             if env.TARGET == "intelfocl"
    #             else "libvta_fsim"
    #         )
    #         # args = str(file_name).split(';')
    #         file_name = str(file_name)
    #         ext_lib = []
    #         # lib_driver = ""
    #         if os.name == 'nt':
    #             lib_driver = find_libvta(lib_driver_name, optional=(not require_sim))
    #             lib_driver = lib_driver[0] + ".a.lib"
    #             ext_lib.append(lib_driver)
    #
    #
    #         """Load module from remote side."""
    #         path = file_name
    #         m = load_module_with_lib(path, extlib=ext_lib)
    #         # logger.info("load_module %s", path)
    #         return m
    #     print('override load_module')

    if env.TARGET == "tsim":
        lib_hw = find_libvta("libvta_hw", optional=True)
        assert lib_hw  # make sure to make in ${VTA_HW_PATH}/hardware/chisel
        f = tvm.get_global_func("vta.tsim.init")
        m = tvm.runtime.load_module(lib_hw[0], "vta-tsim")
        f(m)
        return lib_hw

    return libs


def enabled():
    """Check if simulator is enabled."""
    f = tvm.get_global_func("vta.simulator.profiler_clear", True)
    return f is not None


def clear_stats():
    """Clear profiler statistics."""
    env = get_env()
    if env.TARGET == "sim":
        f = tvm.get_global_func("vta.simulator.profiler_clear", True)
    else:
        f = tvm.get_global_func("vta.tsim.profiler_clear", True)
    if f:
        f()


def stats():
    """Get profiler statistics

    Returns
    -------
    stats : dict
        Current profiler statistics
    """
    env = get_env()
    if env.TARGET == "sim":
        x = tvm.get_global_func("vta.simulator.profiler_status")()
    else:
        x = tvm.get_global_func("vta.tsim.profiler_status")()
    return json.loads(x)


# debug flag to skip execution.
DEBUG_SKIP_EXEC = 1


def debug_mode(flag):
    """Set debug mode
    Paramaters
    ----------
    flag : int
        The debug flag, 0 means clear all flags.
    """
    tvm.get_global_func("vta.simulator.profiler_debug_mode")(flag)


LIBS = _load_sw()

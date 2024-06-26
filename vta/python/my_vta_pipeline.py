import tvm
from tvm.ir import register_intrin_lowering
from vta import transform
from vta.environment import get_env, Environment
from vta.build_module import EarlyRewrite
from pathlib import Path
from typing import Any, Dict, List, Optional
from tvm import IRModule
from vta.support import logging
from vta.build_module import _DebugDump
logger = logging.getLogger(__name__)




def my_build_config(debug_flag=0, **kwargs):
    """Build a build config for VTA.

    Parameters
    ----------
    debug_flag : int
        The dbeug flag to be passed.

    kwargs : dict
        Additional configurations.

    Returns
    -------
    build_config: tvm.transform.PassContext
        The build config that can be used in TVM.

    Example
    --------
    .. code-block:: python

      # build a vta module.
      with vta.build_config():
          vta_module = tvm.build(s, ...)
    """
    env = get_env()

    @tvm.tir.transform.prim_func_pass(opt_level=0)
    def add_debug(f, *_):
        debug = tvm.tir.call_extern("int32", "VTASetDebugMode", env.dev.command_handle, debug_flag)

        return f.with_body(tvm.tir.stmt_seq(debug, f.body))

    pass_list = [
        (0, transform.InjectConv2DTransposeSkip()),
        (0, _DebugDump('after_inject.py', Path('./'))),
        (1, transform.InjectDMAIntrin()),
        (1, _DebugDump('after_injectDMA.py', Path('./'))),
        (1, transform.InjectSkipCopy()),
        (1, transform.AnnotateALUCoProcScope()),
        (1, tvm.tir.transform.LiftAttrScope("coproc_uop_scope")),
        (1, transform.LiftAllocToScopeBegin()),
        (1, tvm.tir.transform.LiftAttrScope("coproc_scope")),
        (1, transform.InjectCoProcSync()),
        (1, EarlyRewrite()),
    ]
    if debug_flag:
        pass_list.append((1, add_debug))
    pass_list.append((2, transform.InjectALUIntrin()))
    pass_list.append((3, tvm.tir.transform.LowerDeviceStorageAccessInfo()))
    pass_list.append((3, transform.FoldUopLoop()))
    pass_list.append((3, transform.CPUAccessRewrite()))
    config = {"tir.add_lower_pass": pass_list}
    if kwargs.get("config"):
        config.update(kwargs[config])
        del kwargs["config"]

    return tvm.transform.PassContext(config=config, **kwargs)


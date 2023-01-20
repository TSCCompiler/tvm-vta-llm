# 从verilog到python代码——使用tvm+verilator的一点简单例子（三）

* 目录
    * 采用TVM Verilator runtime 加载仿真动态库
      * 切分子图
      * 
    * 运行结果
    * TVM+Verilator输出波形


```shell
def @main(%x: Tensor[(8, 4), int32], %y: Tensor[(8, 4), int32]) {
  %0 = add(%x, %y);
  subtract(%0, %y)
}

register make begin and make end
begin to rewrite
begin to annotate args
begin to annotate args
insert make end op
def @main(%x: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */, %y: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */) -> Tensor[(8, 4), int32] {
  %0 = annotation.compiler_begin(%x, compiler="verilator") /* ty=Tensor[(8, 4), int32] */;
  %1 = annotation.compiler_begin(%y, compiler="verilator") /* ty=Tensor[(8, 4), int32] */;
  %2 = add(%0, %1) /* ty=Tensor[(8, 4), int32] */;
  %3 = annotation.compiler_end(%2, compiler="verilator") /* ty=Tensor[(8, 4), int32] */;
  %4 = annotation.compiler_begin(%3, compiler="default") /* ty=Tensor[(8, 4), int32] */;
  %5 = annotation.compiler_begin(%y, compiler="default") /* ty=Tensor[(8, 4), int32] */;
  %6 = subtract(%4, %5) /* ty=Tensor[(8, 4), int32] */;
  annotation.compiler_end(%6, compiler="default") /* ty=Tensor[(8, 4), int32] */
}

def @main(%x: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */, %y: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */) -> Tensor[(8, 4), int32] {
  %0 = @tvmgen_default_verilator_main_0(%x, %y) /* ty=Tensor[(8, 4), int32] */;
  subtract(%0, %y) /* ty=Tensor[(8, 4), int32] */
}

def @tvmgen_default_verilator_main_0(%verilator_0_i0: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */, %verilator_0_i1: Tensor[(8, 4), int32] /* ty=Tensor[(8, 4), int32] */, Inline=1, global_symbol="tvmgen_default_verilator_main_0", Compiler="verilator", Primitive=1) -> Tensor[(8, 4), int32] {
  add(%verilator_0_i0, %verilator_0_i1) /* ty=Tensor[(8, 4), int32] */
}

set wave traced
enter verilator reset 1begin to dump to file 0
end dumping
begin to dump to file 1
end dumping
begin to dump to file 2
end dumping
begin to dump to file 3
end dumping
begin to dump to file 4
end dumping
begin to dump to file 5
end dumping
begin to dump to file 6
end dumping
begin to dump to file 7
end dumping
begin to dump to file 8
end dumping
begin to dump to file 9
end dumping
begin to write
begin to write
begin to read
begin to write
begin to write
...
dealloc context
test:add vector-lanes:1 number of cycles:0

Process finished with exit code 0
```

# /benchmark — Provider 模型测速

测试当前 opencode 配置中所有 Provider 下模型的速度和首 token 延迟。

用法: `/benchmark` 或 `/benchmark jiutian`（只测特定 provider）

执行: 运行 `python3 mix-moma/benchmark_speed.py`，自动发现并测试所有 provider。
输出: 每个 provider 下的模型按 TTFT 和 t/s 排序，标注不可用模型 (HTTP code)。

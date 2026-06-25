# 算法接口规范

## 核心边界

```
Media 层 → AudioBuffer → AlgorithmCore → AlgorithmResult → Export 层
```

算法模块不依赖文件格式、GUI、HTTP。

## 核心类型

- `AudioBuffer`: 统一音频数据
- `AlgorithmResult`: 统一输出
- `AbstractAudioAlgorithm`: 算法基类
- `AbstractRepairAlgorithm`: 修复算法
- `AbstractJoinAlgorithm`: 拼接算法

## 新增算法步骤

1. 定义 struct 继承对应抽象类型
2. 实现 `algorithm_id`
3. 实现 `algorithm_name`
4. 实现 `algorithm_mode`
5. 实现 `parameter_specs`
6. 实现 `process`
7. 在 Registry 注册
8. 添加测试

详见 `docs/plugin_development.md`

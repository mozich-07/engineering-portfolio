# 题库工坊

> P39 · 软件工具与程序练习 · 重点项目

## 功能与当前边界

离线导入 Word、文本与题库数据，支持题目核对、练习、错题本、备份与 Twine 导出。

## 本人工作

独立完成题库解析、核对、练习与错题流程，使用第三方解析库。


## 本地运行

需要 Python 3 与 Node.js，在本项目目录运行：

```text
python work/build.py
node work/engine.test.cjs
node work/export.test.cjs
```

用桌面浏览器打开生成的 `outputs/题库工坊.html`。此目录只带人工编写的演示题，不包含原题集、试题配图、导出成品或用户记录。

代码分为解析/计分引擎、界面和构建脚本。第三方 Mammoth.js 供 Word 解析，SugarCube 仅用于 Twine 兼容测试；两者许可见 `work/`。

## 演示画面

![人工样例题库首页](assets/home.png)

![顺序练习提交后显示解析](assets/practice.png)

## 后续计划

- 维护人工编写的最小样例，补真实文档兼容性测试；原题库和配图不上传。

## 验证记录

本次整理用 Python 生成了离线 HTML，Node.js 通过 10 项引擎测试和 Twine 导出往返测试。覆盖多选计分、跳题分母、答案冲突、图片归属和重复题检查。

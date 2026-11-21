# 孙靖凯的工程作品集

我学电子信息，主要做嵌入式硬件和整机调试。做四足机器人时，我从主控板布线一直跟到舵机上电、回中和装配；做视觉算法时，我用 MATLAB 比较模型，也记录它们在哪些样本上容易出错。

| 代表作品 | 用到的技术 | 我做的部分 |
| --- | --- | --- |
| [灵眸云控 · 四足巡检机器人](projects/quadruped-robot/) | ESP32-C3、双层 PCB、PWM、SolidWorks | 画主控板、焊接上电，参与八路舵机的回中标定，修改打印件以适配装配。[拆盖看主板](projects/quadruped-robot/assets/assembly.jpg) |
| [无碍智饮 · 无障碍饮水机](projects/accessible-water-dispenser/) | STM32F103、手势与语音输入、SolidWorks | 设计换桶辅助结构，参与杯位检测与出水联调，绘制论文结构图。 |
| [道路裂缝检测与形态分类](projects/road-crack-detection/) | MATLAB、CNN、HOG、随机森林 | 从原图划分训练集和测试集，分别评估图块筛查、像素分割和形态分类。34 张测试图派生的 544 个图块上，CNN 筛查 F1 为 0.837。 |

<img src="projects/quadruped-robot/assets/assembly.jpg" width="340" alt="四足机器人拆盖后的主控板与舵机线束">

## 按技术方向浏览

| 方向 | 作品与实践 |
| --- | --- |
| [嵌入式与机器人](collections/embedded/) | ESP32 四足机器人、STM32 桌面宠物、Arduino 交通灯固件 |
| [电子电路与测试](collections/electronics/) | 便携示波器装调、信号发生器、数字钟、焊接与 PCB |
| [结构设计与制造](collections/mechanical/) | SolidWorks 装配设计、CAD 制图、FDM 打印、激光切割 |
| [数字图像处理](collections/imaging/) | 去雾、暗光增强、模糊复原、盲水印、照片转拼豆图纸 |
| [机器学习与信号处理](collections/ml/) | 裂缝识别、目标检测与计数、花卉分类、光纤色散补偿 |
| [软件工具](collections/software/) | 离线题库工坊、就业信息管理网页、Python 小工具 |

想直接看代码，可以从[交通灯控制程序](projects/trafficlight-controller/firmware/TrafficLightController/TrafficLightController.ino)、[拼豆量化与用量统计](projects/bead-pattern-generator/core.js)或[题库解析与计分](projects/quiz-bank-workshop/work/engine.js)开始。

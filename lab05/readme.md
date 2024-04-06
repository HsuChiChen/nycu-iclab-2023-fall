# iclab 05 Matrix convolution, max pooling and transposed convolution
- 時間 : 第6周 2023/10/18(三) - 2023/10/23(一)

## 成績
- 功能正確性 70%
- 效能 = `# of cycle * area` 30% 

我的面積`105220` um^2、執行cycle個數為最小值`1`，效能排名`13`% (`17/134`)，分數`96.46`。

## 規格


## 功能性與優化思路


## 心得


## 優化版本紀錄
### 優化總結


### 第1版
functionality passes
area = `123XXXX`, latency = `45` clock cycles, clock cycle time = `5.2`ns

### 第2版
reduce the latency of mode 1
combine same if condtion
area = `1183740`, latency = `45` cycles for mode 0, latency = `5` cycles for mode 1 , clock cycle time = `5.4`ns

### 第3版
handle image address overflowing condition
first `addr_img_next_row_add4 = addr_img_next_row + 4`, then compare it with `addr_img`
area = `1178681`, latency = `45` cycles for mode 0, latency = `5` cycles for mode 1 , clock cycle time = `5.5`ns
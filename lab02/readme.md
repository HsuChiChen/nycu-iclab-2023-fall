# iclab 02 Calculation on the coordinates
- 時間 : 第3周 2023/09/27(三) - 2023/10/02(一)

## 成績
- 功能正確性 70%
- 效能 = `# of cycle * area` 30% 
- PS : `# of cycle`定義 : `in_valid`(負緣觸發)拉下，`out_valid`(正緣觸發)隔半個cycle拉上來，`# of cycle`算1，依序2, 3, 4, ...。
- cycle time固定12ns。

我的面積`105220` um^2、執行cycle個數為最小值`1`，效能排名`13`% (`17/134`)，分數`96.46`，至於best code的面積是`71051` um^2。

## 規格
有3個mode，input給定4個座標點及mode，在100 cycle數內輸出答案。
- Mode 0 - 梯形渲染，給定4個座標形成的梯形，輸出此梯形包含到的所有座標點。
- Mode 1 - 計算圓和直線關係，給定4個座標，前兩個座標形成一條直線，第三個座標為圓心，第四個座標為圓上一點，輸出此直線與圓的3種相交關係 - 不相交、相切(交於1點)、相割(交於兩點)。
- Mode 2 - 計算面積，給定4個座標，輸出圍成的區域面積。

## 功能性與優化思路


## 心得


## 優化版本紀錄
### 優化總結


### 第1版
I include the point `(-126, -127)` in pattern NO1. of mode 0, but it failed. all pattern in mode 1 and mode 2 passed.

mode 1輸入範圍
```
-2^(N - 1) ~ +2^(N - 1) - 1
-2^5 ~ + 2^5 - 1
-32 ~ 31
```
### 第2版
Functionality passes in all 3 modes with a synthesis area of `398512`.

### 第3版
1. reduce divider from 4 to 2 in mode 0
2. reduce multiplier from 12 to 10 in mode 1
3. reduce multiplier from 8 to 2 in mode 2
, it will get better area `230785`.

### 第4版
In mode 1, share 3 multiplier in 3 cycle in order to reduce multiplier from 10 to 4, it will get better area `217689`.

### 第5版
In mode 2, remove shift 1 bit operation, it will get better area `215617`.

### 第6版
In mode 0, calculate left and right border point based on previous value, it will get better area `134562`.

### 第7版
reduce bit number of wire `outer_product` and `offset` in mode 0, it will get better area `121357`.

### 第8版
reduce bit number of wire `LHS` and `RHS` from 41 bits to 25 bits, it will get better area `118163`.

### 第9版
reduce divider from 2 to 1 in mode 0, it will get better area `108104`.

### 第10版
combine combinational block into sequential block in mode 1, it will get better area `107828`.

### 第11版
remove 16 signals triggered by reset, reserve 5 main signals triggered by reset, it will get better area `105220`.

### 第12版
code formatting
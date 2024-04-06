# Lab00 環境設置
## VSCode remote ssh
```
Host iclab075
  HostName ee30.ee.nctu.edu.tw
  User iclab075
  Port 415
```

## VSCode擴充套件


## `syn.tcl`更改
在`02_SYN/syn.tcl`最後幾行，指令`report_area`加上`-designware -hierarchy`這兩個flag
```
report_area -designware -hierarchy
report_timing 
exit
```
合成出來後會在`02_SYN/syn.log`看到。

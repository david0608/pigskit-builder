# PIKIT Service Release Builder  

利用本專案可以建置用於編譯的環境並編譯 PIKIT service release。  

## 建置 Docker 容器  

因為開發環境的平台不一定會和佈署環境的平台相同，專案中的 Rust 程式會有跨平台的問題。  
若在開發環境上建置一個和佈署環境相同平台(Ubuntu 18.04 x86_64)的容器，則可以借用該容器直接編譯出需要的 target 而不需要進行 cross compile。  
開始編譯專案前須先確定編譯用的 Docker 容器正確運行中。  
操作指令如下(詳細指令請參考 makefile)：  

```
make builder-image          # 製作 builder image
docker images               # 檢視已製作的 image
make builder-container      # 運行 builder container
docker ps -a                # 檢視運行中的 container
```

## 安裝 NodeJS

請使用 node v10.19.0

## 編譯專案  

```
./build.bash
```
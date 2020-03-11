# PIKIT Service Release Builder  

利用本專案可以建置用於編譯的環境並編譯 PIKIT service release。  

## 建置 Docker 容器  

開始編譯專案前須先確定編譯用的 Docker 容器正確運行中。  
操作指令如下(詳細指令請參考 makefile)：  

```
make build-img      # 製作 Docker image
docker images       # 檢視已製作的 image
make run-ctn        # 運行 container
docker ps -a        # 檢視運行中的 container
make login-ctn      # 登入 container

make remove-ctn     # 終止並移除 container
make remove-img     # 移除 image
```

## 編譯專案  

```
./build.bash
```
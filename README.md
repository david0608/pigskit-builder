# PIKIT Service Release Builder  

利用本專案可以建置用於編譯的環境並編譯 PIKIT service release。  
注意：必須將此專案置於 ~/workspace 路徑下

## 利用 Docker 容器編譯 Rust 專案  

利用和佈署環境相同作業系統(Ubuntu x86_64)的容器可以不需進行 cross compile，直接編譯出對應的 Target。  

### 建置 Docker 容器  

開始編譯 Rust 專案前須先確定編譯用的 Docker 容器正確運行中。  
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

### 編譯 rust 專案  

```
make build repo=pikit-graphql-server
make build repo=pikit-restful-server
```
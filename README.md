# Pigskit Service Release Builder  

利用本專案可以建置用於編譯的環境並編譯 Pigskit service release。  

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

## SSL 證書

### Letsencrypt  

參考網路資源為雲端主機取得 Letsencrypt 證書後，需修改檔案的擁有者才能在 pigskit-web container 中存取到  

```
$ sudo su
$ cp /etc/letsencrypt/archive/pigskit.com/* /home/ubuntu/certificate
$ cd /home/ubuntu/certificate
$ chown ubuntu:ubuntu *
$ exit
```

### Self-signed

在本地進行測試時可以為機器產生 self-signed SSL 證書供開發使用：

```
$ cd # path/to/pigskit-builder/certificate
$ openssl req -nodes -new -x509 -keyout privkey.pem -out cert.pem

```

### 運行  

Pigskit-web server 會嘗試檢查所需的檔案是否存在，然後決定是以 https with Letsencrypt、self-signed 或 http 運行。  
若欲以 https with Letsencrypt 運行，例如實際佈署的服務，請確認主機已取得 Letsencrypt 證書，並且將相關檔案放到如下位置：  

```
/home/ubuntu
    |-pigskit
    |   |-app
    |   |-docker
    |   |-postgres
    |-certificate
    |   |-privkey.pem           # server key
    |   |-cert.pem              # server cert
    |   |-chain.pem             # ca
    |...
```

若欲以 https with self-signed 運行，例如在本地進行測試，請確認本機已取得 self-signed 證書，並將相關檔案放到如下位置：  

```
pigskit-builder
    |-certificate
    |   |-privkey.pem           # server key
    |   |-cert.pem              # server cert
    |-pigskit
    |...
```

若上述兩個情況都不滿足，則 pigskit-web server 會以 http 運行。  

## 本地測試

```
cd pigskit/docker && make run       # 運行服務
Ctrl+c && make kill                 # 終止服務
```

## 佈署服務

上傳檔案與登入雲端主機須提供 SSH 金鑰，這裡默認金鑰位置為 ~/.ssh/AwsEcsKey.pem

```
make awsscp                         # 上傳所需的檔案
make awslogin                       # 登入雲端主機
cd ~/pigskit/docker && make run-d   # 運行服務
make kill                           # 終止服務
```
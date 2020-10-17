SHELL := /bin/zsh
image := ubuntu:pigskit-builder
container := pigskit-builder

src/$(repo):
	git clone git@github.com:david0608/$(repo).git src/$(repo)

builder-image:
	docker build -t $(image) ./src/builder

builder-container:
	docker run --name=$(container) -itd -v $$PWD:/root/share $(image)

build-rust: src/$(repo)
	docker exec -it $(container) /bin/bash -c "cd src/$(repo) && cargo build --release"

build-node: src/$(repo)
	cd src/$(repo) && npm install && npm run build

awsscp:
	scp -r -i ~/.ssh/AwsEcsKey.pem pigskit/app pigskit/docker pigskit/sql pigskit/storage $$AWS_NAME:~/pigskit

awslogin:
	ssh -i ~/.ssh/AwsEcsKey.pem $$AWS_NAME
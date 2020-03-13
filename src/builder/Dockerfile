FROM ubuntu:latest
SHELL ["/bin/bash", "-c"]
RUN apt-get update; apt-get install -y curl build-essential
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN echo "export PATH=~/.cargo/bin:\$PATH" >> ~/.bashrc
ENV HOME /root
ENV PATH $HOME/.cargo/bin:$PATH
RUN rustup install nightly; rustup default nightly
WORKDIR /root/share
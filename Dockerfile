FROM debian:jessie
MAINTAINER jonasbn

RUN apt-get update -y
RUN apt-get install -y curl build-essential carton libssl-dev 

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN carton

EXPOSE 3000

CMD carton exec morbo -l https://*:3000 client.pl

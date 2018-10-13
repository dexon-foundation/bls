FROM golang:alpine
MAINTAINER Jimmy Hu <jim2212001@gmail.com>

# Install dependencies
RUN apk add --update-cache build-base gmp-dev openssl-dev git

# Build bls library
RUN mkdir work ; cd work
RUN git clone git://github.com/herumi/mcl.git
RUN mkdir bls
COPY . bls/
RUN cd bls ; make test_go DOCKER=alpine -j && cp lib/* /usr/lib/

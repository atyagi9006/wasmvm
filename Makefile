.PHONY: all build build-rust build-go test docker-image docker-build

DOCKER_TAG := demo
USER_ID := $(shell id -u)
USER_GROUP = $(shell id -g)
FLAGS = RUSTFLAGS='--print=native-static-libs'
# produces:
# note: Link against the following native artifacts when linking against this static library. The order and any duplication can be significant on some platforms.
#  note: native-static-libs: -lutil -lutil -ldl -lrt -lpthread -lgcc_s -lc -lm -lrt -lpthread -lutil -lutil


DLL_EXT = ""
ifeq ($(OS),Windows_NT)
	DLL_EXT = lib
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		DLL_EXT = a
	endif
	ifeq ($(UNAME_S),Darwin)
		DLL_EXT = dylib
	endif
endif

all: build test

build: build-rust build-go

build-rust: build-rust-release strip

# use debug build for quick testing
build-rust-debug:
	$(FLAGS) rustup run nightly cargo build --features backtraces
	cp target/debug/libgo_cosmwasm.$(DLL_EXT) api

# use release build to actually ship - smaller and much faster
build-rust-release:
	$(FLAGS) rustup run nightly cargo build --release --features backtraces
	cp target/release/libgo_cosmwasm.$(DLL_EXT) api
	@ #this pulls out ELF symbols, 80% size reduction!

# implement stripping based on os
ifeq ($(DLL_EXT),so)
strip:
	strip api/libgo_cosmwasm.so
else
# TODO: add for windows and osx
strip:
endif

build-go:
	go build ./...

test:
	RUST_BACKTRACES=1 go test -v . ./api ./types

docker-image:
	docker build . -t confio/go-cosmwasm:$(DOCKER_TAG)

docker-build:
	docker run --rm -u $(USER_ID):$(USER_GROUP) -v $(shell pwd):/code confio/go-cosmwasm:$(DOCKER_TAG)
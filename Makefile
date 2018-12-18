include ../mcl/common.mk
LIB_DIR=lib
OBJ_DIR=obj
EXE_DIR=bin
CFLAGS += -std=c++11
LDFLAGS += -lpthread

SRC_SRC=bls_c256.cpp bls_c384.cpp
TEST_SRC=bls256_test.cpp bls384_test.cpp bls_c256_test.cpp bls_c384_test.cpp
SAMPLE_SRC=bls256_smpl.cpp bls384_smpl.cpp

CFLAGS+=-I../mcl/include -I./
ifneq ($(MCL_MAX_BIT_SIZE),)
  CFLAGS+=-DMCL_MAX_BIT_SIZE=$(MCL_MAX_BIT_SIZE)
endif
ifeq ($(DISABLE_THREAD_TEST),1)
  CFLAGS+=-DDISABLE_THREAD_TEST
endif

SHARE_BASENAME_SUF?=_dy

BLS256_LIB=$(LIB_DIR)/libbls256.a
BLS384_LIB=$(LIB_DIR)/libbls384.a
BLS256_SNAME=bls256$(SHARE_BASENAME_SUF)
BLS384_SNAME=bls384$(SHARE_BASENAME_SUF)
BLS256_SLIB=$(LIB_DIR)/lib$(BLS256_SNAME).$(LIB_SUF)
BLS384_SLIB=$(LIB_DIR)/lib$(BLS384_SNAME).$(LIB_SUF)
all: $(BLS256_LIB) $(BLS256_SLIB) $(BLS384_LIB) $(BLS384_SLIB)

MCL_LIB=../mcl/lib/libmcl.a

$(MCL_LIB):
	$(MAKE) -C ../mcl lib/libmcl.a

$(BLS256_LIB): $(OBJ_DIR)/bls_c256.o
	$(AR) $@ $<
$(BLS384_LIB): $(OBJ_DIR)/bls_c384.o $(MCL_LIB)
	$(AR) $@ $<

ifneq ($(findstring $(OS),mac/mingw64),)
  BLS256_SLIB_LDFLAGS+=-lgmpxx -lgmp -lcrypto -lstdc++
  BLS384_SLIB_LDFLAGS+=-lgmpxx -lgmp -lcrypto -lstdc++
endif
ifeq ($(OS),mingw64)
  CFLAGS+=-I../mcl
  BLS256_SLIB_LDFLAGS+=-Wl,--out-implib,$(LIB_DIR)/lib$(BLS256_SNAME).a
  BLS384_SLIB_LDFLAGS+=-Wl,--out-implib,$(LIB_DIR)/lib$(BLS384_SNAME).a
endif
$(BLS256_SLIB): $(OBJ_DIR)/bls_c256.o $(MCL_LIB)
	$(PRE)$(CXX) -shared -o $@ $< $(MCL_LIB) $(BLS256_SLIB_LDFLAGS)
$(BLS384_SLIB): $(OBJ_DIR)/bls_c384.o $(MCL_LIB)
	$(PRE)$(CXX) -shared -o $@ $< $(MCL_LIB) $(BLS384_SLIB_LDFLAGS)

VPATH=test sample src

.SUFFIXES: .cpp .d .exe

$(OBJ_DIR)/%.o: %.cpp
	$(PRE)$(CXX) $(CFLAGS) -c $< -o $@ -MMD -MP -MF $(@:.o=.d)

$(EXE_DIR)/%384_test.exe: $(OBJ_DIR)/%384_test.o $(BLS384_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BLS384_LIB) -lmcl -L../mcl/lib $(LDFLAGS)

$(EXE_DIR)/%256_test.exe: $(OBJ_DIR)/%256_test.o $(BLS256_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BLS256_LIB) -lmcl -L../mcl/lib $(LDFLAGS)

# sample exe links libbls256.a
$(EXE_DIR)/%.exe: $(OBJ_DIR)/%.o $(BLS256_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BLS256_LIB) -lmcl -L../mcl/lib $(LDFLAGS)

SAMPLE_EXE=$(addprefix $(EXE_DIR)/,$(SAMPLE_SRC:.cpp=.exe))
sample: $(SAMPLE_EXE)

TEST_EXE=$(addprefix $(EXE_DIR)/,$(TEST_SRC:.cpp=.exe))
test: $(TEST_EXE)
	@echo test $(TEST_EXE)
	@sh -ec 'for i in $(TEST_EXE); do $$i|grep "ctest:name"; done' > result.txt
	@grep -v "ng=0, exception=0" result.txt; if [ $$? -eq 1 ]; then echo "all unit tests succeed"; else exit 1; fi
	$(MAKE) sample_test

sample_test: $(EXE_DIR)/bls_smpl.exe
	python bls_smpl.py

ifeq ($(OS),mac)
  MAC_GO_LDFLAGS="-ldflags=-s"
endif
# PATH is for mingw, LD_RUN_PATH is for linux, DYLD_LIBRARY_PATH is for mac
test_go: ffi/go/bls/bls.go ffi/go/bls/bls_test.go $(BLS384_LIB)
	cd ffi/go/bls && go test $(MAC_GO_LDFLAGS) .

EMCC_OPT=-I./include -I./src -I../mcl/include -I./ -Wall -Wextra
EMCC_OPT+=-O3 -DNDEBUG
EMCC_OPT+=-s WASM=1 -s NO_EXIT_RUNTIME=1 -s MODULARIZE=1 #-s ASSERTIONS=1
EMCC_OPT+=-DCYBOZU_MINIMUM_EXCEPTION
EMCC_OPT+=-s ABORTING_MALLOC=0
EMCC_OPT+=-DMCLBN_FP_UNIT_SIZE=6
JS_DEP=src/bls_c384.cpp ../mcl/src/fp.cpp Makefile

../bls-wasm/bls_c.js: $(JS_DEP)
	emcc -o $@ src/bls_c384.cpp ../mcl/src/fp.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=384 -DMCL_USE_WEB_CRYPTO_API -s DISABLE_EXCEPTION_CATCHING=1 -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -DMCL_DONT_USE_CSPRNG -fno-exceptions -MD -MP -MF obj/bls_c384.d

bls-wasm:
	$(MAKE) ../bls-wasm/bls_c.js

clean:
	$(RM) $(OBJ_DIR)/*.d $(OBJ_DIR)/*.o $(EXE_DIR)/*.exe $(GEN_EXE) $(ASM_SRC) $(ASM_OBJ) $(LLVM_SRC) $(BLS256_LIB) $(BLS256_SLIB) $(BLS384_LIB) $(BLS384_SLIB)

ALL_SRC=$(SRC_SRC) $(TEST_SRC) $(SAMPLE_SRC)
DEPEND_FILE=$(addprefix $(OBJ_DIR)/, $(ALL_SRC:.cpp=.d))
-include $(DEPEND_FILE)

.PHONY: test bls-wasm

# don't remove these files automatically
.SECONDARY: $(addprefix $(OBJ_DIR)/, $(ALL_SRC:.cpp=.o))


# TODO: Clean up this file and remove old junk
#

GDB = sudo gdb-multiarch
GCC = i686-elf-gcc
LD	= i686-elf-ld

# Directories
BIN_DIR = ./bin
BUILD_DIR = ./build
SRC_DIR = ./src

# Files
LNK_SCRIPT = ${SRC_DIR}/linker.ld

OS_BIN = ${BIN_DIR}/os.bin

BOOTLOADER = ${SRC_DIR}/boot/bootloader.asm
BOOTLOADER_BIN = ${BIN_DIR}/bootloader.bin

KERNEL_ASM = ${SRC_DIR}/kernel.asm
KERNEL_ASM_OBJ = ${BUILD_DIR}/kernel.asm.o
KERNEL_C = ${SRC_DIR}/kernel.c
KERNEL_C_OBJ = ${BUILD_DIR}/kernel.c.o
#KERNEL_BIN = ${BIN_DIR}/kernel.bin

KERNEL_FINAL_OBJ = ${BUILD_DIR}/kernel_final.asm.o
KERNEL_FINAL_BIN = ${BIN_DIR}/kernel_final.bin

# All obj files needed to build the final full kernel
#KERNEL_OBJ_FILES = ${KERNEL_ASM_OBJ} ${KERNEL_C_OBJ} 


# Flags
ASM_FLAGS = -g -Werror -w+all
LD_FLAGS = -g -relocatable
GCC_FLAGS = -g -ffreestanding -falign-jumps -falign-functions -falign-labels -falign-loops -fstrength-reduce -fomit-frame-pointer -finline-functions -Wno-unused-function -fno-builtin -Werror -Wno-unused-label -Wno-cpp -Wno-unused-parameter -nostdlib -nostartfiles -nodefaultlibs -Wall -O0 -Iinc

INCLUDE_DIRS := $(shell find $(SRC_DIR) -type d)
INCLUDES = $(patsubst %, -I%, $(INCLUDE_DIRS))

# Find all C source files in src directory
KERNEL_C_SOURCES := $(shell find $(SRC_DIR) -name '*.c')
KERNEL_ASM_SOURCES := $(filter-out ${BOOTLOADER}, $(shell find $(SRC_DIR) -name '*.asm'))

# Generate corresponding object files in build directory
KERNEL_C_OBJECTS := $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.c.o, $(KERNEL_C_SOURCES))
KERNEL_ASM_OBJECTS := $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/%.asm.o, $(KERNEL_ASM_SOURCES))
KERNEL_OBJ_FILES := ${KERNEL_C_OBJECTS} ${KERNEL_ASM_OBJECTS}


KERNEL_OBJ_FILES := ${KERNEL_ASM_OBJ} $(filter-out ${KERNEL_ASM_OBJ}, ${KERNEL_OBJ_FILES})






${info ${KERNEL_ASM_SOURCES}}
${info ${KERNEL_C_OBJECTS}}
${info ${KERNEL_ASM_OBJECTS}}
${info ${KERNEL_OBJ_FILES}}





# ##################################################################################
# Build Commands
# ##################################################################################
all: prereqs | ${BOOTLOADER_BIN} ${KERNEL_FINAL_BIN}
	# Create a bootable floppy of our OS
	dd if=/dev/zero    		  of=${OS_BIN} bs=512 count=2880
	dd if=${BOOTLOADER_BIN}   of=${OS_BIN} bs=512 seek=0 count=1   conv=notrunc,sync
	dd if=${KERNEL_FINAL_BIN} of=${OS_BIN} bs=512 seek=1 count=100 conv=notrunc,sync

# Build Kernel
# ############

# Build our final kernel binary from all our kernel obj files
${KERNEL_FINAL_BIN}: ${KERNEL_C_OBJECTS} ${KERNEL_ASM_OBJECTS}
#${KERNEL_FINAL_BIN}: ${KERNEL_OBJ_FILES}
	# Combine all kernel object files into one BIG object file
	${LD} ${LD_FLAGS} -o ${KERNEL_FINAL_OBJ} ${KERNEL_OBJ_FILES}
	# Using the linker script assemble our object files into 1 final binary
	#${GCC} ${GCC_FLAGS} -T ${LNK_SCRIPT} -o ${KERNEL_FINAL_BIN} ${KERNEL_FINAL_OBJ}
	${GCC} ${GCC_FLAGS} -T ${LNK_SCRIPT} -o ${KERNEL_FINAL_BIN} ${KERNEL_FINAL_OBJ}
	# Remove the executable bit from final binary as gcc sets it
	chmod -x ${KERNEL_FINAL_BIN}


# Compile .c files
${BUILD_DIR}/%.c.o: ${SRC_DIR}/%.c
	mkdir -p $(dir $@)
	${GCC} ${INCLUDES} ${GCC_FLAGS} -std=gnu99 -c $< -o $@

# Compile .asm files
${BUILD_DIR}/%.asm.o: ${SRC_DIR}/%.asm
	mkdir -p $(dir $@)
	nasm ${ASM_FLAGS} -f elf -o $@ $<



## This is the initial Kernel code in assembly
#${KERNEL_ASM_OBJ}: ${KERNEL_ASM}
#	nasm ${ASM_FLAGS} -f elf -o ${KERNEL_ASM_OBJ} ${KERNEL_ASM}
#
#${KERNEL_C_OBJ}: ${KERNEL_C}
#	${GCC} ${INCLUDES} ${GCC_FLAGS} -std=gnu99 -c ${KERNEL_C} -o ${KERNEL_C_OBJ}






# Build Bootloader
# ################

$(BOOTLOADER_BIN): ${BOOTLOADER}
	nasm ${ASM_FLAGS} -f bin ${BOOTLOADER} -o ${BOOTLOADER_BIN}


prereqs:
	mkdir -p ${BIN_DIR} ${BUILD_DIR}


# ##################################################################################
# Helper Commands
# ##################################################################################
.PHONY: run clean debug compiledb
run: all
	qemu-system-x86_64 -hda ${OS_BIN}

debug: all
	${GDB} \
		-ex 'set disassembly-flavor intel' \
		-ex 'set disassembly-next-line on' \
		-ex 'set auto-load off' \
		-ex 'add-symbol-file ${KERNEL_FINAL_OBJ} 0x100000' \
		-ex 'target remote | qemu-system-x86_64 -hda ${OS_BIN} -S -gdb stdio' \
		-ex 'break *0x7c00' \
		-ex 'continue'

clean:
	rm -rf ${BIN_DIR}
	rm -rf ${BUILD_DIR}

compiledb:
	make clean
	rm -f ./compile_commands.json
	bear -- make -B


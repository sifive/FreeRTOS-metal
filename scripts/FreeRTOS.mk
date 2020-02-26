#
# Copyright 2019 SiFive, Inc #
# SPDX-License-Identifier: Apache-2.0 #
#

# FREERTOS_DIR=$(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))FreeRTOS-Kernel
# FREERTOS_MEMMANG_DIR =${FREERTOS_DIR}/portable/MemMang

# SOURCE_DIR ?= ../FreeRTOS-Kernel

# ----------------------------------------------------------------------
# CORE PART
# ----------------------------------------------------------------------
# FREERTOS_C_SOURCES = croutine.c
# FREERTOS_C_SOURCES += event_groups.c
# FREERTOS_C_SOURCES += list.c
# FREERTOS_C_SOURCES += queue.c
# FREERTOS_C_SOURCES += stream_buffer.c
# FREERTOS_C_SOURCES += tasks.c
# FREERTOS_C_SOURCES += timers.c
override SOURCE_DIRS := $(SOURCE_DIR)

# ----------------------------------------------------------------------
# Add Platform port - Here file for RISC-V port
# ----------------------------------------------------------------------
# FREERTOS_C_SOURCES += port.c
# FREERTOS_C_SOURCES += pmp.c
# FREERTOS_S_SOURCES += portASM.S
override SOURCE_DIRS += $(SOURCE_DIR)/portable/GCC/RISC-V

# ----------------------------------------------------------------------
# Add common directory for all Platform port 
# ----------------------------------------------------------------------
# FREERTOS_C_SOURCES += mpu_wrappers.c
ifeq ($(PMP),ENABLE)
	override SOURCE_DIRS += $(SOURCE_DIR)/portable/Common
endif

# ---------------------------------------------------------------------
override C_SOURCES := $(foreach dir,$(SOURCE_DIRS),$(wildcard $(dir)/*.c))

override ASM_SOURCES := $(foreach dir,$(SOURCE_DIRS),$(wildcard $(dir)/*.[Ss])) \
						$(foreach dir,$(SOURCE_DIRS),$(wildcard $(dir)/*.asm))

# ----------------------------------------------------------------------
# Define HEAP managment model
# ----------------------------------------------------------------------
ifeq ($(HEAP),1)
	C_SOURCES += $(SOURCE_DIR)/portable/MemMang/heap_1.c
else ifeq ($(HEAP),2)
	C_SOURCES += $(SOURCE_DIR)/portable/MemMang/heap_2.c
else ifeq ($(HEAP),3)
	C_SOURCES += $(SOURCE_DIR)/portable/MemMang/heap_3.c
else ifeq ($(HEAP),4)
	C_SOURCES += $(SOURCE_DIR)/portable/MemMang/heap_4.c
else ifeq ($(HEAP),5)
	C_SOURCES += $(SOURCE_DIR)/portable/MemMang/heap_5.c
else
	ERR = $(error No heap management selected)
endif

# ----------------------------------------------------------------------
# Includes Location
# ----------------------------------------------------------------------
# FREERTOS_INCLUDES := -I${FREERTOS_DIR}/include
# FREERTOS_INCLUDES += -I${FREERTOS_MEMMANG_DIR}
# FREERTOS_INCLUDES += -I${FREERTOS_DIR}/portable/GCC/RISC-V
# FREERTOS_INCLUDES += -I${FREERTOS_DIR}/portable/GCC/RISC-V/chip_specific_extensions/RV32I_CLINT_no_extensions

# ----------------------------------------------------------------------
# Modify the VPATH
# ----------------------------------------------------------------------
# VPATH:=${FREERTOS_DIR}:${FREERTOS_MEMMANG_DIR}:${FREERTOS_DIR}/portable/GCC/RISC-V:${FREERTOS_DIR}/portable/Common:${VPATH}
# $(info vpath = $(VPATH))

override INCLUDES := $(foreach dir,$(INCLUDE_DIRS),$(wildcard $(dir)/*.h))

override C_OBJS := $(subst $(SOURCE_DIR),$(BUILD_DIR),$(C_SOURCES:.c=.o))
override ASM_OBJS := 	$(subst $(SOURCE_DIR),$(BUILD_DIR), $(patsubst %.S,%.o,$(filter %.S,$(ASM_SOURCES))))\
						$(subst $(SOURCE_DIR),$(BUILD_DIR), $(patsubst %.s,%.o,$(filter %.s,$(ASM_SOURCES))))\
						$(subst $(SOURCE_DIR),$(BUILD_DIR), $(patsubst %.asm,%.o,$(filter %.asm,$(ASM_SOURCES))))

override OBJS := $(C_OBJS) $(ASM_OBJS)
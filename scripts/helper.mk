#
# Copyright 2020 SiFive, Inc #
# SPDX-License-Identifier: Apache-2.0 #
#

ifeq ($(FREERTOS_DIR),)
	ERR = $(error Please specify FreeRTOS main directory by using FREERTOS_DIR variable )
else 
endif



ifeq ($(portHANDLE_INTERRUPT),)
	ERR = $(error Please specify portHANDLE_INTERRUPT by using portHANDLE_INTERRUPT variable )
endif

ifeq ($(portHANDLE_EXCEPTION),)
	ERR = $(error Please specify portHANDLE_EXCEPTION by using portHANDLE_EXCEPTION variable )
endif

ifeq ($(MTIME_CTRL_ADDR),)
	ERR = $(error Please specify mtime controller address by using MTIME_CTRL_ADDR variable )
endif

ifeq ($(MTIME_RATE_HZ),)
	ERR = $(error Please specify MTIME_RATE_HZ by using MTIME_RATE_HZ variable )
endif

ifeq ($(FREERTOS_CONFIG_DIR),)
	ERR = $(error Please specify FreeRTOSConfig.h driectory by using FREERTOS_CONFIG_DIR variable ) 
endif

# ----------------------------------------------------------------------
# CORE PART
# ----------------------------------------------------------------------
override FREERTOS_INCLUDE_DIRS := $(FREERTOS_INCLUDE_DIR)

# ----------------------------------------------------------------------
# Add Platform port - Here file for RISC-V port
# ----------------------------------------------------------------------
override FREERTOS_INCLUDE_DIRS += $(FREERTOS_SOURCE_DIR)/portable/GCC/RISC-V

# ----------------------------------------------------------------------
# Add Platform port - Here file for RISC-V port specific to SiFive
# ----------------------------------------------------------------------
override FREERTOS_INCLUDE_DIRS += $(FREERTOS_SOURCE_DIR)/portable/GCC/RISC-V/chip_specific_extensions/RV32I_CLINT_no_extensions

################################################################################
#                        COMPILATION FLAGS
################################################################################

override FREERTOS_CFLAGS := -DMTIME_RATE_HZ=$(MTIME_RATE_HZ) \
							-DportHANDLE_INTERRUPT=$(portHANDLE_INTERRUPT) \
							-DportHANDLE_EXCEPTION=$(portHANDLE_EXCEPTION) \
							-DMTIME_CTRL_ADDR=$(MTIME_CTRL_ADDR)

override FREERTOS_CFLAGS += $(foreach dir,$(FREERTOS_INCLUDE_DIRS),-I $(dir)) -I $(FREERTOS_CONFIG_DIR)

override FREERTOS_ASFLAGS = $(FREERTOS_CFLAGS)
#
# Copyright 2019 SiFive, Inc #
# SPDX-License-Identifier: Apache-2.0 #
#

ifeq ($(FREERTOS_DIR),)
	ERR = $(error Please specify FreeRTOS directory by using FREERTOS_DIR variable )
endif

# ----------------------------------------------------------------------
# Includes Location
# ----------------------------------------------------------------------
override FREERTOS_INCLUDES := $(FREERTOS_DIR)/FreeRTOS-Kernel/include
override FREERTOS_INCLUDES += $(FREERTOS_DIR)/FreeRTOS-Kernel/portable/GCC/RISC-V
override FREERTOS_INCLUDES += $(FREERTOS_DIR)/FreeRTOS-Kernel/portable/GCC/RISC-V/chip_specific_extensions/RV32I_CLINT_no_extensions

# Check if systemview is enable
FILTER_SYSVIEW:=freeRTOS.define.configUSE_SEGGER_SYSTEMVIEW
ifneq ($(filter $(FILTER_SYSVIEW),$(MAKE_CONFIG)),)
	ifeq ($(SEGGER_SYSTEMVIEW_INCLUDES),)
		ERR = $(error Undefine SEGGER_SYSTEMVIEW_INCLUDES, whether SystemView is activated)
	else 
		override FREERTOS_INCLUDES += $(SEGGER_SYSTEMVIEW_INCLUDES)
	endif
endif

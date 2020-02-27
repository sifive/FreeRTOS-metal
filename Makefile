
override CURRENT_DIR := $(patsubst %/,%, $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

override SOURCE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel
BUILD_DIR ?= $(CURRENT_DIR)/build
override INCLUDE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel/include

include scripts/FreeRTOS_core.mk

################################################################################
#                                CHECKS
################################################################################

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

################################################################################
#                                HEADER TEMPLATE
################################################################################

HEADER_TEMPLATES := $(CURRENT_DIR)/templates/Bridge_Freedom-metal_FreeRTOS.h.in

override INCLUDE_DIRS += $(BUILD_DIR)/include

################################################################################
#                        COMPILATION FLAGS
################################################################################
override CFLAGS += $(foreach dir,$(INCLUDE_DIRS),-I $(dir)) -I $(FREERTOS_CONFIG_DIR)

override ASFLAGS = $(CFLAGS)

ifeq ($(origin ARFLAGS),default)
	ifeq ($(VERBOSE),TRUE)
		override ARFLAGS :=	cruv
	else
		override ARFLAGS :=	cru
	endif
else
	ifeq ($(VERBOSE),TRUE)
		ARFLAGS ?= cruv
	else
		ARFLAGS ?= cru
	endif
endif

################################################################################
#                               MACROS
################################################################################
ifeq ($(VERBOSE),TRUE)
	HIDE := 
else
	HIDE := @
endif

################################################################################
#                                RULES
################################################################################

libFreeRTOS.a : headers $(OBJS)
	$(HIDE) mkdir -p $(BUILD_DIR)/lib
	$(HIDE) $(AR) $(ARFLAGS) $(BUILD_DIR)/lib/libFreeRTOS.a $(OBJS)

headers :
	$(HIDE) mkdir -p $(BUILD_DIR)/include
	python3 $(CURRENT_DIR)/scripts/parser_auto_header.py --input_file $(HEADER_TEMPLATES) --output_dir $(BUILD_DIR)/include

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.c err headers
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -c -o $@ $(CFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.S err headers
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.s err headers
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.asm err headers
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

.PHONY: test_config_file
test_config_file: 
	$(ERR)

.PHONY: err
err: 
	$(ERR)

.PHONY : check-format
check-format:
	clang-format -i $(SOURCES) $(INCLUDES)

.PHONY : clean
clean:
	rm -rf ./$(BUILD_DIR)

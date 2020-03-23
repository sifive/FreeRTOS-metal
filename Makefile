
override CURRENT_DIR := $(patsubst %/,%, $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

override SOURCE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel
BUILD_DIR ?= $(CURRENT_DIR)/build
override INCLUDE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel/include

include scripts/FreeRTOS_core.mk

################################################################################
#                                CHECKS
################################################################################

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

export MAKE_CONFIG

################################################################################
#                                RULES
################################################################################

libFreeRTOS.a : headers $(OBJS)
	$(HIDE) mkdir -p $(BUILD_DIR)/lib
	$(HIDE) $(AR) $(ARFLAGS) $(BUILD_DIR)/lib/libFreeRTOS.a $(OBJS)

headers : venv/.stamp
	$(HIDE) mkdir -p $(BUILD_DIR)/include
	. venv/bin/activate && python3 $(CURRENT_DIR)/scripts/parser_auto_header.py --input_file $(HEADER_TEMPLATES) --output_dir $(BUILD_DIR)/include

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

test_config : venv/.stamp
	$(info MAKE_CONFIG:$(MAKE_CONFIG))
	. venv/bin/activate && python3 $(CURRENT_DIR)/scripts/parser_auto_header.py

venv/.stamp: venv/bin/activate requirements.txt
	. venv/bin/activate && pip install --upgrade pip
	. venv/bin/activate && pip install -r requirements.txt
	@echo "Remember to source venv/bin/activate!"
	touch $@

venv/bin/activate:
	python3 -m venv venv

.PHONY: err
err: 
	$(ERR)

.PHONY : check-format
check-format:
	clang-format -i $(SOURCES) $(INCLUDES)

.PHONY : clean
clean:
	rm -rf ./$(BUILD_DIR)

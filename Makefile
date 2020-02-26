
override CURRENT_DIR := $(patsubst %/,%, $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

override SOURCE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel
BUILD_DIR ?= $(CURRENT_DIR)/build
override INCLUDE_DIR := $(CURRENT_DIR)/FreeRTOS-Kernel/include

include scripts/FreeRTOS.mk

################################################################################
#                        COMPILATION FLAGS
################################################################################

# ifeq ($(RISCV_ARCH),)
# 	ERR = $(error Please specify -march by using RISCV_ARCH variable )
# endif

# ifeq ($(RISCV_ABI),)
# 	ERR = $(error Please specify -mabi by using RISCV_ABI variable )
# endif

# ifeq ($(RISCV_CMODEL),)
# 	ERR = $(error Please specify -mcmodel by using RISCV_CMODEL variable )
# endif

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

# override CFLAGS +=  -march=$(RISCV_ARCH) \
# 					-mabi=$(RISCV_ABI) \
# 					-mcmodel=$(RISCV_CMODEL) \
# 					-ffunction-sections \
# 					-fdata-sections \
# 					-finline-functions \
# 					--specs=nano.specs 

override CFLAGS += 	-DMTIME_RATE_HZ=$(MTIME_RATE_HZ) \
					-DportHANDLE_INTERRUPT=$(portHANDLE_INTERRUPT) \
					-DportHANDLE_EXCEPTION=$(portHANDLE_EXCEPTION) \
					-DMTIME_CTRL_ADDR=$(MTIME_CTRL_ADDR)

# override IFLAGS = $(foreach dir,$(INCLUDE_DIRS),-I $(dir)) -I $(FREERTOS_CONFIG_DIR)

override CFLAGS += $(foreach dir,$(INCLUDE_DIRS),-I $(dir)) -I $(FREERTOS_CONFIG_DIR)

override ASFLAGS = $(CFLAGS)

ifeq ($(origin ARFLAGS),default)
	override ARFLAGS :=	cru
else
	ARFLAGS ?= cru
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

libFreeRTOS.a : $(OBJS)
	$(HIDE) $(HIDE) mkdir -p $(BUILD_DIR)/lib
	$(HIDE) $(AR) $(ARFLAGS) $(BUILD_DIR)/lib/libFreeRTOS.a $(OBJS)

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.c err
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -c -o $@ $(CFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.S err
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.s err
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.asm err
	$(HIDE) mkdir -p $(dir $@)
	$(HIDE) $(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $<

.PHONY : print_info
print_info:
	$(info ASM_SOURCES:$(ASM_SOURCES))
	$(info ASM_OBJS:$(ASM_OBJS))

	$(info .S:$(filter %.S,$(ASM_SOURCES)))
	$(info .s:$(filter %.s,$(ASM_SOURCES)))
	$(info .asm:$(filter %.asm,$(ASM_SOURCES)))

	$(info subst .S:)
	$(info subst .S:$(subst $(SOURCE_DIR),$(BUILD_DIR), $(patsubst %.s,%.o,$(filter %.s,$(ASM_SOURCES)))))
	$(info subst .S:$(subst $(SOURCE_DIR),$(BUILD_DIR), $(patsubst %.asm,%.o,$(filter %.asm,$(ASM_SOURCES)))))

.PHONY: err
err: 
	$(ERR)

.PHONY : check-format
check-format:
	clang-format -i $(SOURCES) $(INCLUDES)

.PHONY : clean
clean:
	rm -rf ./$(BUILD_DIR)

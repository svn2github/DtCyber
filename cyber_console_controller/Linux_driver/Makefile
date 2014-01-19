#--------------------------------------------------------------------------
#
#   Copyright (c) 2013, Tom Hunter (see license.txt)
#
#   Name: Makefile
#
#   Description:
#       Build CDC CYBER and 6600 channel PCI card driver.
#
#--------------------------------------------------------------------------

# Comment/uncomment the following line to disable/enable debugging
DEBUG = n

# Add your debugging flag (or not) to EXTRA_CFLAGS
ifeq ($(DEBUG),y)
    DEBFLAGS = -O -g -DDEV_DEBUG # "-O" is needed to expand inlines
else
    DEBFLAGS = -O2
endif

EXTRA_CFLAGS += $(DEBFLAGS)
EXTRA_CFLAGS += -I$(LDDINC)

ifneq ($(KERNELRELEASE),)
# call from kernel build system

obj-m	:= cyber_channel.o 

else

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD       := $(shell pwd)

all: modules cctest

modules:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) LDDINC=$(PWD)/../include modules

endif

cctest: cctest.c
	$(CC) -o $@ $@.c

clean:
	rm -rf *.o *~ core .depend .*.cmd *.ko *.mod.c .tmp_versions cctest

depend .depend dep:
	$(CC) $(EXTRA_CFLAGS) -M *.c > .depend

ifeq (.depend,$(wildcard .depend))
include .depend
endif

#---------------------------  End Of File  --------------------------------

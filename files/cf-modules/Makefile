KVER ?= $(shell rpm -q kernel-longterm --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n1)
KDIR ?= /lib/modules/$(KVER)/build

obj-m += panel-cwd686.o
obj-m += panel-cwu50.o
obj-m += panel-cwu50-cm3.o
obj-m += ocp8178_bl.o
obj-m += axp20x-i2c.o
obj-m += axp20x_ac_power.o
obj-m += axp20x_battery.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a $(KVER)

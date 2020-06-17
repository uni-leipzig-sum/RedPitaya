#
# Red Pitaya fast counter server.
# @author: Lukas Botsch <lukas.botsch@uni-leipzig.de>
#

APP=$(notdir $(CURDIR:%/=%))

# Installation directory. It is changed when using the main Makefile++++++
INSTALL_DIR ?= /opt/redpitaya

CNTSRV=counter-server
ARTIFACTS= $(CNTSRV)

DEBUG ?= 0

all: $(CNTSRV)

$(CNTSRV):
	$(MAKE) -C src

install:
	mkdir -p $(INSTALL_DIR)/bin
	cp $(CNTSRV) $(INSTALL_DIR)/bin

clean:
	$(MAKE) -C src clean

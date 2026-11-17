# Ф0 fit check: the zxuno module of EXP28 alone, XC6SLX25-2, -iobuf NO
#   make          run XST (zxuno_measure.syr)
#   make report   utilization from the .syr
ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh
XIL = source $(ISE_SETTINGS) > /dev/null;
SHELL = /bin/bash
SRC = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' zxuno_measure.prj)

all: zxuno_measure.ngc
zxuno_measure.ngc: zxuno_measure.prj zxuno_measure.xst $(SRC) ../rtl/zxuno/config/config.vh
	mkdir -p xstm/projnav.tmp
	$(XIL) xst -intstyle ise -ifn zxuno_measure.xst -ofn zxuno_measure.syr > xst.log 2>&1 || (tail -30 xst.log; false)
report:
	@sed -n '/Slice Logic Utilization/,/Specific Feature Utilization/p;/Number of Block RAM/,/DSP48A1s/p;/Minimum period/p' zxuno_measure.syr
clean:
	rm -rf xstm zxuno_measure.ngc zxuno_measure.ngr zxuno_measure.syr zxuno_measure.lso zxuno_measure_xst.xrpt xst.log _xmsgs
.PHONY: all report clean

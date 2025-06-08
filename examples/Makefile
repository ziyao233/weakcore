CC		?= cc
CCAS		= $(CC)
LD		= $(CC)
OBJCOPY		= objcopy

LDSCRIPT	= link.ld

MYCFLAGS	= -nostdlib -nostdinc -I$(INCLUDE)	\
		  -I$(THISBOARD)/ -march=rv32i		\
		  -mcmodel=medany -mabi=ilp32 -g -O0 $(CFLAGS)
MYLDFLAGS	= -Wl,-T$(LDSCRIPT) -nostdlib $(LDFLAGS)

OBJS		:= start.o main.o
KERNEL		:= test.elf
BINARY		:= test.bin

default: build

build: $(BINARY)

$(BINARY): $(KERNEL)
	$(OBJCOPY) $(KERNEL) -O binary -j .text -j .data $(BINARY)

$(KERNEL): $(OBJS)
	$(LD) $(MYLDFLAGS) $(OBJS) -o $(KERNEL)

clean:
	-rm $(OBJS)

disbuild: clean
	-rm $(KERNEL)

%.o: %.S
	$(CCAS) $< -c $(MYCFLAGS) -o $@

%.o: %.c
	$(CC) $< -c $(MYCFLAGS) -o $@

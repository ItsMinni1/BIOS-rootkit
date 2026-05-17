ASM=nasm
QEMU=qemu-system-x86_64
SRC_BOOT=boot.asm
SRC_PAYLOAD=payload.asm
BIN_BOOT=boot.bin
BIN_PAYLOAD=payload.bin
IMG=bootkit.img

all: $(IMG)

$(BIN_BOOT): $(SRC_BOOT)
	$(ASM) -f bin $(SRC_BOOT) -o $(BIN_BOOT)

$(BIN_PAYLOAD): $(SRC_PAYLOAD)
	$(ASM) -f bin $(SRC_PAYLOAD) -o $(BIN_PAYLOAD)

$(IMG): $(BIN_BOOT) $(BIN_PAYLOAD)
	# Combine MBR and Payload. MBR is 512 bytes, Payload follows.
	cat $(BIN_BOOT) $(BIN_PAYLOAD) > $(IMG)
	# Ensure the image is at least 1024 bytes (2 sectors)
	truncate -s 1024 $(IMG)

run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)

clean:
	rm -f $(BIN_BOOT) $(BIN_PAYLOAD) $(IMG)

.PHONY: all run clean

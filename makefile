###############################################################################
## Makefile for DynoSprite

# paths
SRCDIR = ./engine
GAMEDIR = ./game
SCRIPTDIR = ./scripts
BUILDDIR = ./build
TOOLDIR = ./tools
TILEDIR = $(GAMEDIR)/tiles
LEVELDIR = $(GAMEDIR)/levels
SPRITEDIR = $(GAMEDIR)/sprites
OBJECTDIR = $(GAMEDIR)/objects
SOUNDDIR = $(GAMEDIR)/sounds
IMAGEDIR = $(GAMEDIR)/images
GENASMDIR = $(BUILDDIR)/asm
GENOBJDIR = $(BUILDDIR)/obj
GENLISTDIR = $(BUILDDIR)/list
GENDISKDIR = $(BUILDDIR)/disk

# lists of source game assets
TILEDESC = $(wildcard $(TILEDIR)/??-*.txt)
LEVELSRC = $(wildcard $(LEVELDIR)/??-*.asm)
SPRITESRC = $(wildcard $(SPRITEDIR)/??-*.spr)
OBJECTSRC = $(wildcard $(OBJECTDIR)/??-*.asm)
SOUNDSRC = $(wildcard $(SOUNDDIR)/??-*.wav)
IMAGESRC = $(wildcard $(IMAGEDIR)/??-*.png)
LEVELSRC = $(wildcard $(LEVELDIR)/??-*.asm)
LEVELDSC = $(wildcard $(LEVELDIR)/??-*.txt)

# lists of build products based on game assets
TILESRC = $(patsubst $(TILEDIR)/%.txt, $(GENOBJDIR)/tileset%.txt, $(TILEDESC))
PALSRC = $(patsubst $(TILEDIR)/%.txt, $(GENOBJDIR)/palette%.txt, $(TILEDESC))
SPRITERAW := $(patsubst $(SPRITEDIR)/%.spr, $(GENOBJDIR)/sprite%.raw, $(SPRITESRC))
OBJECTRAW := $(patsubst $(OBJECTDIR)/%.asm, $(GENOBJDIR)/object%.raw, $(OBJECTSRC))
SOUNDRAW := $(patsubst $(SOUNDDIR)/%.wav, $(GENOBJDIR)/sound%.raw, $(SOUNDSRC))
LEVELRAW := $(patsubst $(LEVELDIR)/%.asm, $(GENOBJDIR)/level%.raw, $(LEVELSRC))
MAPSRC := $(patsubst $(LEVELDIR)/%.txt, $(GENOBJDIR)/tilemap%.txt, $(LEVELDSC))

# output ASM files generated from sprites
SPRITEASMSRC := $(patsubst $(SPRITEDIR)/%.spr, $(GENASMDIR)/sprite%.asm, $(filter %.spr, $(SPRITESRC)))

# paths to dependencies
COCODISKGEN = $(TOOLDIR)/file2dsk
ASSEMBLER = $(TOOLDIR)/lwasm
EMULATOR = $(TOOLDIR)/mess64

# make sure build products directories exist
$(shell mkdir -p $(GENASMDIR))
$(shell mkdir -p $(GENOBJDIR))
$(shell mkdir -p $(GENLISTDIR))
$(shell mkdir -p $(GENDISKDIR))

# assembly source files
LOADERSRC = $(addprefix $(SRCDIR)/, constants.asm \
                                    datastruct.asm \
                                    decompress.asm \
                                    disk.asm \
                                    globals.asm \
                                    graphics-bkgrnd.asm \
                                    graphics-image.asm \
                                    graphics-sprite.asm \
                                    graphics-text.asm \
                                    input.asm \
                                    loader.asm \
                                    macros.asm \
                                    main.asm \
                                    math.asm \
                                    memory.asm \
                                    menu.asm \
                                    object.asm \
                                    sound.asm \
                                    system.asm \
                                    utility.asm)

# files to be added to Coco3 disk image
READMEBAS = $(GENDISKDIR)/README.BAS
LOADERBIN = $(GENDISKDIR)/DYNO.BIN
DATA_TILES = $(GENDISKDIR)/TILES.DAT
DATA_OBJECTS = $(GENDISKDIR)/OBJECTS.DAT
DATA_LEVELS = $(GENDISKDIR)/LEVELS.DAT
DATA_SOUNDS = $(GENDISKDIR)/SOUNDS.DAT
DATA_IMAGES = $(GENDISKDIR)/IMAGES.DAT
DISKFILES = $(READMEBAS) $(LOADERBIN) $(DATA_TILES) $(DATA_OBJECTS) $(DATA_LEVELS) $(DATA_SOUNDS) $(DATA_IMAGES)

# game directory files to be included in core pass2 assembly
ASM_TILES = $(GENASMDIR)/gamedir-tiles.asm
ASM_OBJECTS = $(GENASMDIR)/gamedir-objects.asm
ASM_LEVELS = $(GENASMDIR)/gamedir-levels.asm
ASM_SOUNDS = $(GENASMDIR)/gamedir-sounds.asm
ASM_IMAGES = $(GENASMDIR)/gamedir-images.asm

# core assembler pass outputs
PASS1LIST = $(GENLISTDIR)/dynosprite-pass1.lst
PASS2LIST = $(GENLISTDIR)/dynosprite-pass2.lst
SYMBOLASM = $(GENASMDIR)/dynosprite-symbols.asm

# retrieve the audio sampling rate
AUDIORATE = $(shell grep -E "AudioSamplingRate\s+EQU\s+[0-9]+" $(SRCDIR)/globals.asm | grep -oE "[0-9]+")

# options
ifneq ($(RELEASE), 1)
  ASMFLAGS += --define=DEBUG
endif
ifeq ($(SPEEDTEST), 1)
  ASMFLAGS += --define=SPEEDTEST
endif
ifeq ($(VISUALTIME), 1)
  ASMFLAGS += --define=VISUALTIME
endif
ifeq ($(CPU),6309)
  ASMFLAGS += --define=CPU=6309
  LOADERSRC += $(SRCDIR)/graphics-blockdraw-6309.asm
else
  CPU = 6809
  ASMFLAGS += --define=CPU=6809
  LOADERSRC += $(SRCDIR)/graphics-blockdraw-6809.asm
endif
ifeq ($(MAMEDBG), 1)
  MAMEFLAGS += -debug
endif

# output disk image filename
TARGET = DYNO$(CPU).DSK

# build targets
targets:
	@echo "DynoSprite makefile. "
	@echo "  Targets:"
	@echo "    all           == Build disk image"
	@echo "    clean         == remove binary and output files"
	@echo "    test          == run test in MAME"
	@echo "  Build Options:"
	@echo "    RELEASE=1     == build without bounds checking / SWI instructions"
	@echo "    SPEEDTEST=1   == run loop during idle and count time for analysis"
	@echo "    VISUALTIME=1  == set screen width to 256 and change border color"
	@echo "    CPU=6309      == build with faster 6309-specific instructions"
	@echo "  Debugging Options:"
	@echo "    MAMEDBG=1     == run MAME with debugger window (for 'test' target)"


all: $(TARGET)

clean:
	rm -rf $(GENASMDIR) $(GENOBJDIR) $(GENDISKDIR) $(GENLISTDIR)

test:
	$(EMULATOR) coco3h -flop1 $(TARGET) $(MAMEFLAGS) -window -waitvsync -resolution 640x480 -video opengl -rompath /mnt/terabyte/pyro/Emulators/firmware/

# build rules

# 0. Build dependencies
$(COCODISKGEN): $(TOOLDIR)/src/file2dsk/main.c
	gcc -o $@ $<

# 1a. Generate text Palette and Tileset files from images
$(GENOBJDIR)/tileset%.txt $(GENOBJDIR)/palette%.txt: $(TILEDIR)/%.txt
	$(SCRIPTDIR)/gfx-process.py gentileset $< $(GENOBJDIR)/palette$*.txt $(GENOBJDIR)/tileset$*.txt

# 1b. Generate text Tilemap files from images
$(GENOBJDIR)/tilemap%.txt: $(LEVELDIR)/%.txt $(TILESRC) $(PALSRC)
	$(SCRIPTDIR)/gfx-process.py gentilemap $< $(GENOBJDIR) $@

# 2. Compile sprites to 6809 assembly code
$(GENASMDIR)/sprite%.asm: $(SPRITEDIR)/%.spr $(SCRIPTDIR)/sprite2asm.py
	$(SCRIPTDIR)/sprite2asm.py $< $@ $(CPU)

# 3. Assemble sprites to raw machine code
$(GENOBJDIR)/sprite%.raw: $(GENASMDIR)/sprite%.asm
	$(ASSEMBLER) $(ASMFLAGS) -r -o $@ --list=$(GENLISTDIR)/sprite$*.lst --symbols $<

# 4. Run first-pass assembly of DynoSprite engine
$(PASS1LIST): $(LOADERSRC)
	$(ASSEMBLER) $(ASMFLAGS) --define=PASS=1 -b -o /dev/null --list=$(PASS1LIST) --symbols $(SRCDIR)/main.asm

# 5. Extract symbol addresses from DynoSprite engine
$(SYMBOLASM): $(SCRIPTDIR)/symbol-extract.py $(PASS1LIST)
	$(SCRIPTDIR)/symbol-extract.py $(PASS1LIST) $(SYMBOLASM)

# 6. Assemble Object handling routines to raw machine code
$(GENOBJDIR)/object%.raw: $(OBJECTDIR)/%.asm $(SRCDIR)/datastruct.asm $(SYMBOLASM)
	$(ASSEMBLER) $(ASMFLAGS) -r -I $(SRCDIR) -I $(GENASMDIR)/ -o $@ --list=$(GENLISTDIR)/object$*.lst --symbols $<

# 7. Assemble Level handling routines to raw machine code
$(GENOBJDIR)/level%.raw: $(LEVELDIR)/%.asm $(SRCDIR)/datastruct.asm $(SYMBOLASM)
	$(ASSEMBLER) $(ASMFLAGS) -r -I $(SRCDIR) -I $(GENASMDIR)/ -o $@ --list=$(GENLISTDIR)/level$*.lst --symbols $<

# 8. Build Object data file and game directory assembler code
$(DATA_OBJECTS) $(ASM_OBJECTS): $(SCRIPTDIR)/build-objects.py $(SPRITERAW) $(OBJECTRAW)
	$(SCRIPTDIR)/build-objects.py $(GENOBJDIR) $(GENLISTDIR) $(GENDISKDIR) $(GENASMDIR)

# 9. Build Level data file and game directory assembler code
$(DATA_LEVELS) $(ASM_LEVELS): $(SCRIPTDIR)/build-levels.py $(PASS1LIST) $(LEVELRAW) $(MAPSRC) $(LEVELDSC)
	$(SCRIPTDIR)/build-levels.py $(LEVELDIR) $(PASS1LIST) $(GENOBJDIR) $(GENLISTDIR) $(GENDISKDIR) $(GENASMDIR)

#10. Build Tileset data file and game directory assembler code
$(DATA_TILES) $(ASM_TILES): $(SCRIPTDIR)/build-tiles.py $(TILESRC) $(PALSRC)
	$(SCRIPTDIR)/build-tiles.py $(GENOBJDIR) $(GENDISKDIR) $(GENASMDIR)

#11. Resample audio files
$(GENOBJDIR)/sound%.raw: $(SOUNDDIR)/%.wav
	echo Converting audio waveform: $<
	ffmpeg -v warning -i $< -acodec pcm_u8 -f u8 -ac 1 -ar $(AUDIORATE) -af aresample=$(AUDIORATE):filter_size=256:cutoff=1.0 $@

#12. Build Sound data file and game directory assembler code
$(DATA_SOUNDS) $(ASM_SOUNDS): $(SCRIPTDIR)/build-sounds.py $(SOUNDRAW)
	$(SCRIPTDIR)/build-sounds.py  $(GENOBJDIR) $(GENDISKDIR) $(GENASMDIR)

#13. Build Images data file and game directory assembler code
$(DATA_IMAGES) $(ASM_IMAGES): $(SCRIPTDIR)/build-images.py $(IMAGESRC)
	$(SCRIPTDIR)/build-images.py  $(IMAGEDIR) $(GENDISKDIR) $(GENASMDIR)

#14. Run final assembly pass of DynoSprite engine and relocate code sections
$(LOADERBIN): $(LOADERSRC) $(ASM_TILES) $(ASM_OBJECTS) $(ASM_LEVELS) $(ASM_SOUNDS) $(ASM_IMAGES) $(SCRIPTDIR)/binsectionmover.py
	$(ASSEMBLER) $(ASMFLAGS) --define=PASS=2 -b -I $(GENASMDIR)/ -o $(LOADERBIN) --list=$(PASS2LIST) $(SRCDIR)/main.asm
	$(SCRIPTDIR)/binsectionmover.py $(LOADERBIN) 0e00-1fff 4000 e000-ffff 6000

#15. Generate the README.BAS document
$(READMEBAS): $(SCRIPTDIR)/build-readme.py $(GAMEDIR)/readme-bas.txt
	$(SCRIPTDIR)/build-readme.py $(GAMEDIR)/readme-bas.txt $(READMEBAS)

#16. Create Coco disk image (file2dsk))
$(TARGET): $(COCODISKGEN) $(DISKFILES)
	rm -f $(TARGET)
	$(COCODISKGEN) $(TARGET) $(DISKFILES)

.PHONY: all clean test


title := p8crt
version := wip
objlist := popslide16 crt0 p8crt pads ppuclear nstripe  \
  hello chrrom
linkscript := nrom256.x

# The Windows Python installer puts py.exe in the path, but not
# python3.exe, which confuses MSYS Make.  COMSPEC will be set to
# the name of the shell on Windows and not defined on UNIX.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

EMU := fceux
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/FCEUX/fceux.exe

# Clear out unused
.SUFFIXES:

objdir := obj/nes
srcdir := src
imgdir := tilesets

# Compensate for Windows/UNIX differences
ifdef COMSPEC
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

# Phony targets
.PHONY: run debug all clean dist zip
run: $(title).nes
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<
all: $(title).nes
clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr
dist: zip
zip: $(title)-$(version).zip

$(title).nes map.txt: $(linkscript) $(foreach o,$(objlist),$(objdir)/$(o).o)
	ld65 -o $(title).nes -m map.txt -C $^ nes.lib

# Generic compilation rules
$(objdir)/%.o: $(objdir)/%.s
	ca65 -o $@ $<

$(objdir)/%.o: $(srcdir)/%.s
	ca65 -o $@ $<

$(objdir)/%.s: $(srcdir)/%.c
	cc65 -Oi -o $@ $<

$(objdir)/%.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py --planes "0;1" $< $@

# Files that include other files
$(objdir)/chrrom.o: $(objdir)/bggfx.chr

# Packaging

$(title)-$(version).zip: \
  zip.in $(title).nes README.md $(objdir)/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@

# Build zip.in from the list of files in the Git tree
zip.in: makefile $(title).nes
	git ls-files | grep -e "^[^.]" > $@
	echo $(title).nes >> $@
	echo zip.in >> $@

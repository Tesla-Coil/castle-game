# Use this Makefile only with GNU make
# (GNU make is the standard make on Linux,
# on Windows it comes with FPC or Cygwin or MinGW,
# on FreeBSD it is gmake).

# ------------------------------------------------------------
# Various targets.

default: build

# make sure that various files are up-to-date
update:
	$(MAKE) -C source/
	$(MAKE) -C data/items/life_potion/
	$(MAKE) -C data/items/sword/
	$(MAKE) -C data/levels/

# Simple install.
# You may as well symlink to /usr/local/share/castle, for system-wide install.
install:
	rm -f $(HOME)/.castle.data
	ln -s $(shell pwd) $(HOME)/.castle.data

# ------------------------------------------------------------
# Building targets.
#
# You may wish to call target `clean' before
# calling build targets. This will make sure that everything is
# compiled with appropriate options (suitable for release or debugging).
#
# For some debug compilation features, use DEBUG=xxx make option:
# - DEBUG=t
#   makes normal debug build (debug checks, etc.)
# - DEBUG=valgrind
#   makes a compilation for profiling with valgrind (callgrind, massif).
#   This compiles -dRELEASE code, but still with debug symbols, line info etc.
#   for valgrind.
# - DEBUG=gprof
#   makes a compilation for profiling with gprof.
# Otherwise normal optimized release build will be done.

ifeq ($(DEBUG),t)
FPC_OPTIONS := -dDEBUG
else
ifeq ($(DEBUG),valgrind)
FPC_OPTIONS := -gl -gv -dRELEASE
else
ifeq ($(DEBUG),gprof)
FPC_OPTIONS := -pg -dRELEASE
else
FPC_OPTIONS := -dRELEASE
endif
endif
endif

FPC_OPTIONS := $(FPC_OPTIONS) -dCASTLE_WINDOW_BEST_NOGUI @castle-fpc.cfg

# Extension of executable is determined by target operating system,
# that in turn depends on 1. -T options in CASTLE_FPC_OPTIONS and
# 2. current OS, if no -T inside CASTLE_FPC_OPTIONS. It's easiest to just
# use "fpc -iTO", to avoid having to detect OS (or parse CASTLE_FPC_OPTIONS)
# in the Makefile.
TARGET_OS = $(shell fpc -iTO $${CASTLE_FPC_OPTIONS:-})
EXE_EXTENSION = $(shell if '[' $(TARGET_OS) '=' 'win32' ']'; then echo '.exe'; else echo ''; fi)

build:
# clean-window to force rebuilding CastleWindow unit with proper backend.
	$(MAKE) -C ../castle_game_engine/ clean-window
	@echo 'Target OS exe extension detected: "'$(EXE_EXTENSION)'"'
	cd ../castle_game_engine/ && \
	  fpc $(FPC_OPTIONS) $${CASTLE_FPC_OPTIONS:-} ../castle/source/castle.lpr
	mv source/castle$(EXE_EXTENSION) ./
	cd ../castle_game_engine/ && \
	  fpc $(FPC_OPTIONS) $${CASTLE_FPC_OPTIONS:-} ../castle/source/castle-process-3d-model.lpr
	mv source/castle-process-3d-model$(EXE_EXTENSION) ./

# ------------------------------------------------------------
# Cleaning targets.

# Clean files which are easily recoverable, or just temporary trash
# (after compilers or editors).
# This does not include compiled "castle" binaries, but it *does*
# include "castle-process-3d-model" binaries (as I don't want to pack
# them in releases).
clean:
	find . -type f '(' -iname '*.ow'  -or -iname '*.ppw' -or -iname '*.aw' -or \
	                   -iname '*.o'   -or -iname '*.ppu' -or -iname '*.a' -or \
	                   -iname '*.dcu' -or -iname '*.dpu' -or \
			   -iname '*~' -or \
	                   -iname '*.~???' -or \
			   -iname 'castle.compiled' -or \
			   -iname '*.blend1' ')' -print \
	     | xargs rm -f
# I recurse into source/ subdir only if it exists ---
# this is useful because this may be called by pack_binary.sh
# script inside a temporary copy of castle files, where source/
# subdirectory isn't supposed to exist.
	if [ -d source/ ]; then $(MAKE) -C source/ clean; fi
	rm -f castle-process-3d-model castle-process-3d-model.exe
	rm -Rf data/levels/fountain/fluidcache/

clean_binaries:
	rm -f castle castle.exe

# Remove private files that Michalis keeps inside his castle/trunk/,
# but he doesn't want to upload them for public.
#
# These things are *not* automatically generated (automatically generated
# stuff is removed always by `clean'). So this target is supposed to be
# used only by pack_*.sh scripts,
# it does it inside temporary copy of castle/trunk/.
#
# Notes: I remove here data/sounds/intermediate/, because it's large
# and almost noone should need this. These files are downloadable from
# internet anyway, as they are just original things used to make
# some sounds.
clean_private:
	find . -type d '(' -iname '.svn' ')' -print \
	     | xargs rm -Rf
	rm -Rf data/sounds/intermediate/

# eof ------------------------------------------------------------

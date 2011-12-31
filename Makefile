# Use this Makefile only with GNU make
# (GNU make is the standard make on Linux,
# on Windows it comes with FPC or Cygwin or MinGW,
# on FreeBSD it is gmake).

# ------------------------------------------------------------
# Various targets.

# default: make sure that various files are up-to-date, and show info
default: info
	$(MAKE) -C source/
	$(MAKE) -C data/items/life_potion/
	$(MAKE) -C data/items/sword/
	$(MAKE) -C data/levels/

# This is deliberately a "=" variable, not ":=", so it's expanded only
# when needed (not for any compilation)
VERSION = $(shell castle --version)

info:
	@echo 'Version is '$(VERSION)

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
FPC_UNIX_OPTIONS := -dDEBUG
FPC_WINDOWS_OPTIONS := -dDEBUG
else

ifeq ($(DEBUG),valgrind)
FPC_UNIX_OPTIONS := -gl -gv -dRELEASE -dCASTLE_WINDOW_XLIB
FPC_WINDOWS_OPTIONS := -gl -gv -dRELEASE
else

ifeq ($(DEBUG),gprof)
FPC_UNIX_OPTIONS := -pg -dRELEASE -dCASTLE_WINDOW_XLIB
FPC_WINDOWS_OPTIONS := -pg -dRELEASE
else

FPC_UNIX_OPTIONS := -dRELEASE -dCASTLE_WINDOW_XLIB
FPC_WINDOWS_OPTIONS := -dRELEASE
endif
endif
endif

build-unix: clean-window
	cd ../castle_game_engine/ && \
	  fpc $(FPC_UNIX_OPTIONS) "$${CASTLE_FPC_OPTIONS:-}" \
	  @castle-fpc.cfg ../castle/source/castle.lpr
	mv source/castle ./
	cd ../castle_game_engine/ && \
	  fpc $(FPC_UNIX_OPTIONS) "$${CASTLE_FPC_OPTIONS:-}" \
	  @castle-fpc.cfg ../castle/source/castle-process-3d-model.lpr
	mv source/castle-process-3d-model ./

build-windows: clean-window
	cd ../castle_game_engine/ && \
	  fpc $(FPC_WINDOWS_OPTIONS) "$${CASTLE_FPC_OPTIONS:-}" \
	  @castle-fpc.cfg ../castle/source/castle.lpr
	mv source/castle.exe ./castle.exe
	cd ../castle_game_engine/ && \
	  fpc $(FPC_WINDOWS_OPTIONS) "$${CASTLE_FPC_OPTIONS:-}" \
	  @castle-fpc.cfg ../castle/source/castle-process-3d-model.lpr
	mv source/castle-process-3d-model.exe ./castle-process-3d-model.exe

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

# Force rebuilding CastleWindow unit with proper backend.
clean-window:
	$(MAKE) -C ../castle_game_engine/ clean-window

# ----------------------------------------
# Set SVN tag.

svntag:
	svn copy http://svn.code.sf.net/p/castle-engine/code/trunk/castle \
	         http://svn.code.sf.net/p/castle-engine/code/tags/castle/$(VERSION) \
	  -m "Tagging the $(VERSION) version of 'The Castle'."

# eof ------------------------------------------------------------

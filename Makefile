# Makefile: build libS52.so for openev plugin
#
# SD AUG2004
# SD FEB2008   - clean up, fix some deps
# SD JUL2008   - move test stuff
# SD JUL2008   - add pkg-config
# SD JAN2009   - mod clean up
# SD JUN2009   - fix s52gv
# SD FEB2010   - fix s52gv2 (now default)
# SD 2011NOV08 - add s52eglarm (android)
# SD 2012NOV04 - add Parson lib (simple JSON parser) to handle SOCK stream
# SD 2012NOV05 - move sduc-git.txt note inside Makefile (bottom)
# SD 2013AUG31 - add s52gtk3egl
# SD 2014FEB11 - add s52eglw32, s52gtk2egl


##### TARGETS #########
#all: s52glx         # OGR & GLX
#all: s52eglx        # OGR & EGL & X11   (for testing EGL/GLES2 on X)
#all: s52eglarm      # OGR & EGL & ARM   (for testing EGL/GLES2 on ARM/Android)
#all: s52eglw32      # OGR & EGL & Win32 (for testing EGL/GLES2 on Win32)
#all: s52gv          # GV  (GTK)
#all: s52gv2         # GV2 (GTK2)
all: s52gtk2        # OGR & GTK2 & GL 1.x (broken)
#all: s52gtk2p       # profiling
#all: s52gtk2gps     # build s52gtk2 for testing with live data comming from GPSD
#all: s52gtk2egl     # GTK2 & EGL
#all: s52gtk3egl     # GTK3 & EGL
#all: s52qt4         # OGR & Qt4 (build s52gtk2 to run on Qt4)
#all: s52win32       # build s52gtk2 to run on wine/win32 (MinGW)
#all: s52clutter     # use COGL for rendering text
#all: s52clutter.js  # use COGL for rendering text and Javascript


SHELL = /bin/sh

.PHONY: test/* clean


DBG0   = -O0 -g
DBG1   = -O0 -g1 -Wall -pedantic -Wextra
DBG2   = -O0 -g2 -Wall -pedantic -Wextra
DBG3   = -O0 -g3 -Wall -pedantic -Wextra -ggdb3 -rdynamic -fstack-protector-all
DBGOFF = -DG_DISABLE_ASSERT
DBG    = $(DBG2)

# from clutter
# Compiler flags: -Werror -Wall -Wshadow -Wcast-align -Wno-uninitialized -Wempty-body -Wformat-security -Winit-self

# from /.
#MALLOC_CHECK_=3, gcc's _FORTIFY_SOURCE=2 define, gcc's -fmudflap flag, gcc's -Wall -Wextra and -pedantic flags;

# GO -fdump-go-spec=S52.go to generate symbol for GO

# -Weffc++
# Causes GCC to check for the 50 specific C++ suggestions in Scott Meyers famous book 'Effective C++'

#CC   = tcc -fPIC
#CXX  = tcc -fPIC -fmudflap
#CC   = gcc -std=c99 -fPIC -DMALLOC_CHECK_=3 -D_FORTIFY_SOURCE=2
#CC   = gcc -std=c99 -fPIC
CC   = gcc -std=gnu99 -fPIC # need gnu99 to get M_PI
#CC   = g++ -fPIC
CXX  = g++ -fPIC

# win32: check this   _MINGW32_
s52win32 : MINGW = /usr/bin/i586-mingw32msvc-
s52win32 : CC    = $(MINGW)gcc -g -O0 -Wall -DG_DISABLE_ASSERT -D_MINGW -std=c99
s52win32 : CXX   = $(MINGW)g++ -g -O0 -Wall -DG_DISABLE_ASSERT -D_MINGW
#s52win32 : CC    = winegcc -g -std=c99 -O0 -Wall -DG_DISABLE_ASSERT -D_MINGW

#s52eglw32: MINGW = /usr/bin/i686-w64-mingw32-
s52eglw32: MINGW = /usr/bin/i586-mingw32msvc-
s52eglw32: CC    = $(MINGW)gcc -g -O0 -Wall -DG_DISABLE_ASSERT -D_MINGW -m32 -std=gnu99
s52eglw32: CXX   = $(MINGW)g++ -g -O0 -Wall -DG_DISABLE_ASSERT -D_MINGW -m32

s52win32 : CXX  = $(CC)     # hack
s52gv    : CXX  = $(CC)     # hack
s52gv2   : CXX  = $(CC)     # hack

s52win32 s52eglw32: LIBWIN32PATH = ../../mingw

TAGS     = ctags

SRCS_S52 = S52GL.c S52PL.c S52CS.c S57ogr.c S57data.c S52MP.c S52utils.c S52.c
OBJS_S52 = $(SRCS_S52:.c=.o) S52raz-3.2.rle.o

OBJS_GV  = gvS57layer.o S57gv.o

OBJS_FREETYPE_GL = ./lib/freetype-gl/vector.o ./lib/freetype-gl/texture-atlas.o ./lib/freetype-gl/texture-font.o

# Note: there is no GLU for ARM, the code handle tessallation by converting double->float on the fly,
# so the tess code is pulled from COGL.
# (Quadric are also in GLU, but it is done by hand in S52GL.c to output float
# for VBO in GLES2 for circle / disk / arc.)
OBJS_TESS = ./lib/tesselator/dict.o      ./lib/tesselator/geom.o     \
            ./lib/tesselator/mesh.o      ./lib/tesselator/normal.o   \
            ./lib/tesselator/priorityq.o ./lib/tesselator/render.o   \
            ./lib/tesselator/sweep.o     ./lib/tesselator/tessmono.o \
            ./lib/tesselator/tess.o

# handle JSON in WebSocket
OBJ_PARSON = ./lib/parson/parson.o

OPENEV_HOME  = `pwd -P`/../../openev-cvs
OPENEV2_HOME = `pwd -P`/../../../openev2/trunk/src/lib/gv
#GV2LIBS      = /usr/local/lib/python2.6/dist-packages/openev/_gv.so



############### CFLAGS setup ##############################
#
#

# NOTE: -malign-double: for 32bits system --useless on 64its

# NOTE: GV_USE_DOUBLE_PRECISION_COORD not needed directly for S52
#       but gvtype.h need it and it can be pulled in (somehow.)
# NOTE: 'gdal-config --cflags': need with mingw
# NOTE: -D_REENTRANT add this if threading
# NOTE: signal is handled by glib-2.0 as of gtk+-2.0
# NOTE: -DS52_USE_SUPP_LINE_OVERLAP, experiment in progresse to suppress overlapping lines
#      (GDAL/OGR/S57 need a patch to work as it max out)
#
# NOTE: *** experimental ***
# -DS52_USE_COGL: used to test text rendering from COGL
# -DS52_USE_FTGL: text rendering
# -DS52_USE_GLC : text rendering
# -DS52_USE_FREETYPE_GL: text rendering need -DS52_USE_GLES2
# -DS52_USE_OGR_FILECOLLECTOR:
#        - compile with g++ to use gdal/ogr s57filecollector()
#        - add 'extern "C"' to ogr/ogrsf_frmts/s57.h:40 S57FileCollector()  -or- compile S52 with g++
#        - for Windows file path in CATALOG to work on unix apply patch in doc/s57filecollector.cpp.diff
# -DS52_USE_SUPP_LINE_OVERLAP: supress display of overlapping line  (OGR patch in doc/ogrfeature.cpp.diff)
#                              --see S52 manual p. 45 doc/pslb03_2.pdf
# -DS52_USE_C_AGGR_C_ASSO: return info C_AGGR C_ASSO on cursor pick (OGR patch in doc/ogrfeature.cpp.diff)
# -DS52_USE_SYM_AISSEL01: need symbol in test/plib-test-priv.rle
# -DS52_USE_SYM_AISVES01_RED: close quarter, need symbol in PLAUX_00.DAI
# -DS52_USE_WORLD: need shapefile WORLD_SHP in S52.c:201 ("--0WORLD.shp")
#


# -DS52_DEBUG: add more info for debugging libS52 (ex _checkError() in S52GL.c)
# -DS52_USE_LOG: log every S52_* in tmp file
#
# -DS52_USE_OPENGL_VBO: GL version 1.5 or greater.
# -DS52_USE_EGL:  for GLES2
# -DS52_USE_DBUS: mimic S52.h
# -DS52_USE_SOCK: same as DBus
# -DS52_USE_PIPE: same as DBus, in a day
# -DS52_USE_GOBJECT
# -DS52_USE_BACKTRACE

CFLAGS = `pkg-config  --cflags glib-2.0 lcms ftgl gl`  \
         `gdal-config --cflags`                        \
         -DS52_USE_DOTPITCH                            \
         -DS52_USE_FTGL                                \
         -DS52_USE_GLIB2                               \
         -DS52_USE_PROJ                                \
         -DS52_USE_OPENGL_VBO                          \
         -DS52_DEBUG $(DBG)

s52clutter, s52clutter.js :                                 \
         CFLAGS = `pkg-config  --cflags glib-2.0 lcms ftgl` \
         `gdal-config --cflags`                             \
         -I/home/sduclos/dev/gis/gdal/gdal/frmts/iso8211/   \
         -DS52_USE_DOTPITCH                                 \
         -DS52_USE_GLIB2                                    \
         -DS52_USE_PROJ                                     \
         -DS52_USE_OGR_FILECOLLECTOR                        \
         -DS52_USE_BACKTRACE                                \
         -DS52_USE_GOBJECT                                  \
         -DS52_DEBUG $(DBG)

s52gtk2p : CFLAGS += -pg

s52glx : CFLAGS = `pkg-config  --cflags glib-2.0` \
                  `gdal-config --cflags`          \
                  -DS52_USE_PROJ                  \
                  -DS52_USE_DOTPITCH $(DBG)

# GL - EGL/GL 1.x broken
#s52gtk3egl s52eglx : CFLAGS = `pkg-config  --cflags glib-2.0 lcms egl gl`
# -DS52_USE_WORLD
s52eglx s52gtk2egl s52gtk3egl : CFLAGS =         \
                  `pkg-config  --cflags glib-2.0 lcms egl glesv2` \
                  `gdal-config --cflags`         \
                  -I/usr/include                 \
                  -I/usr/include/freetype2       \
                  -I./lib/freetype-gl            \
                  -I./lib/tesselator             \
                  -I./lib/parson                 \
                  -DS52_USE_PROJ                 \
                  -DS52_USE_GLIB2                \
                  -DS52_USE_DOTPITCH             \
                  -DS52_USE_BACKTRACE            \
                  -DS52_USE_OPENGL_VBO           \
                  -DS52_USE_EGL                  \
                  -DS52_USE_GLES2                \
                  -DS52_USE_FREETYPE_GL          \
                  -DS52_USE_SOCK                 \
                  -DS52_USE_OGR_FILECOLLECTOR    \
                  -DS52_USE_SYM_VESSEL_DNGHL     \
                  -DS52_DEBUG $(DBG)

# WARNING: gdal run OK on android with android-9-toolchain
# NOT android-14-toolchain (libsupc++ missing)
# CFLAGS="-mthumb" CXXFLAGS="-mthumb" LIBS="-lstdc++" ./configure --host=arm-eabi \
# --without-grib --prefix=/home/sduclos/dev/prog/Android/dev/ --enable-shared=no --without-ld-shared

# using Android toolchain from NDK to cross compile for ARM (s52eglarm target)
#s52eglarm : ARMTOOLCHAINROOT = /home/sduclos/dev/prog/Android/dev/android-9-toolchain
#s52eglarm : ARMTOOLCHAINROOT = /home/sduclos/dev/prog/Android/dev/android-14-toolchain
s52eglarm : ARMTOOLCHAINROOT = /home/sduclos/dev/prog/Android/dev/android-19-toolchain
s52eglarm : ARMINCLUDE       = $(ARMTOOLCHAINROOT)/sysroot/usr/include
s52eglarm : ARMLIBS          = $(ARMTOOLCHAINROOT)/sysroot/usr/lib

# Android 4.4.2: -O2 -O1 crash activity android:name = ".s52ui"
s52eglarm : CC     = $(ARMTOOLCHAINROOT)/bin/arm-linux-androideabi-gcc -fPIC -mthumb -std=c99
s52eglarm : CXX    = $(ARMTOOLCHAINROOT)/bin/arm-linux-androideabi-g++ -fPIC -mthumb
s52eglarm : AR     = $(ARMTOOLCHAINROOT)/bin/arm-linux-androideabi-ar
s52eglarm : RANLIB = $(ARMTOOLCHAINROOT)/bin/arm-linux-androideabi-ranlib

s52eglarm : S52DROIDINC = /home/sduclos/S52/test/android/dist/system/include
s52eglarm : S52DROIDLIB = /home/sduclos/S52/test/android/dist/system/lib

# -DS52_USE_SYM_AISSEL01 - experimental - symbol in plib-test-priv.rle
# -DS52_USE_BACKTRACE    - debug
# -DS52_USE_SOCK         - socket & WebSocket
# -DS52_USE_WORLD        - experimental - load world Shapefile
# -DS52_USE_OPENGL_VBO   -
# -DS52_USE_FREETYPE_GL  - need GLES2
# -DS52_USE_GLES2        - need VBO, EGL
# -DS52_USE_TEGRA2       - must be in sync with Android.mk (Xoom)
# -DS52_USE_ADRENO       - must be in sync with Android.mk (Nexus 7)
# -DS52_USE_LOG          - log S52_* call to tmp file
# -DS52_DEBUG            - enable debug code, PRINTF()
# -DG_DISABLE_ASSERT     - disable g_assert()

              DEFS = -DS52_USE_GLIB2                       \
                     -DS52_USE_PROJ                        \
                     -DS52_USE_DOTPITCH                    \
                     -DS52_USE_EGL                         \
                     -DS52_USE_GLES2                       \
                     -DS52_USE_OPENGL_VBO                  \
                     -DS52_USE_FREETYPE_GL                 \
                     -DS52_USE_ANDROID                     \
                     -DS52_USE_TEGRA2                      \
                     -DS52_USE_OGR_FILECOLLECTOR           \
                     -DS52_USE_SUPP_LINE_OVERLAP           \
                     -DS52_USE_SOCK                        \
                     -DG_DISABLE_ASSERT

s52eglarm : CFLAGS = -I$(S52DROIDINC)                      \
                     -I$(S52DROIDINC)/glib-2.0             \
                     -I$(S52DROIDINC)/glib-2.0/include     \
                     -I/usr/include/freetype2              \
                     -I./lib/freetype-gl                   \
                     -I./lib/tesselator                    \
                     -I./lib/parson                        \
                     $(DEFS)


s52eglios : IOS_PLATFORM = iphonesimulator
s52eglios : IOS_ARCH = arm7s

s52eglios : CC     = `xcrun --sdk $(IOS_PLATFORM) clang`
s52eglios : CXX    = `xcrun --sdk $(IOS_PLATFORM) clang++`
s52eglios : AR     = `xcrun --sdk $(IOS_PLATFORM) ar`
s52eglios : RANLIB = `xcrun --sdk $(IOS_PLATFORM) ranlib`

s52eglios : S52IOSSDK = `xcrun --show-sdk-path --sdk $(IOS_PLATFORM)`

              DEFS = -DS52_USE_PROJ                        \
                     -DS52_USE_DOTPITCH                    \
                     -DS52_USE_EGL                         \
                     -DS52_USE_GLES2                       \
                     -DS52_USE_OPENGL_VBO                  \
                     -DS52_USE_FREETYPE_GL                 \
                     -DS52_USE_OGR_FILECOLLECTOR           \
                     -DS52_USE_SUPP_LINE_OVERLAP           \
                     -DS52_USE_SOCK                        \
                     -DG_DISABLE_ASSERT

s52eglios : CFLAGS = -arch $(IOS_ARCH)                     \
                     -pipe                                 \
					 -Os                                   \
					 -gdwarf-2                             \
					 -I/usr/include/freetype2              \
	                 -I./lib/freetype-gl                   \
                     -I./lib/tesselator                    \
                     -I./lib/parson                        \
                     $(DEFS)


#s52eglios : CC = xcrun --sdk iphoneos clang
#s52eglios : CXX = xcrun --sdk iphoneos clang++


# check this; gv use glib-1 S52 use glib-2
#                 -DS52_USE_PROJ
s52gv  : CFLAGS = `glib-config --cflags`                \
                  `gdal-config --cflags`                \
                  -DS52_USE_GV $(DBG)                   \
                  -DGV_USE_DOUBLE_PRECISION_COORD       \
                  `gtk-config --cflags` -I$(OPENEV_HOME)

s52gv2 : CFLAGS = `pkg-config  --cflags glib-2.0 lcms`  \
                  `gdal-config --cflags`                \
                  -DS52_USE_GV                          \
                  -DS52_USE_GLIB2                       \
                  -DGV_USE_DOUBLE_PRECISION_COORD       \
                  -DS52_USE_DOTPITCH $(DBG)             \
                  -I$(OPENEV2_HOME)

s52gtk2gps:  CFLAGS = `pkg-config  --cflags glib-2.0 lcms ftgl dbus-1 dbus-glib-1`   \
                      `gdal-config --cflags`            \
                      -DS52_USE_DOTPITCH                \
                      -DS52_USE_FTGL                    \
                      -DS52_USE_GLIB2                   \
                      -DS52_USE_PROJ                    \
                      -DS52_USE_OGR_FILECOLLECTOR       \
                      -DS52_USE_SUPP_LINE_OVERLAP       \
                      -DS52_USE_DBUS                    \
                      -DS52_USE_GOBJECT                 \
                      -DS52_USE_BACKTRACE               \
                      -DS52_DEBUG $(DBG)

#  -I../../../../graphic/cms/lcms-1.17-mingw/include
#  -DS52_DEBUG $(DBG)
#  -DS52_USE_LOG
#  -DS52_USE_SUPP_LINE_OVERLAP
#s52win32 : CFLAGS = `pkg-config  --cflags glib-2.0 lcms`
#s52win32  : GDALPATH = ../../../gdal/gdal-1.6.0-mingw/
#        -I../../../proj4/proj-4.6.1-mingw/src
s52win32 : GDALPATH = ../../../gdal/gdal-1.7.2-mingw/
s52win32 : CFLAGS   = -mms-bitfields                         \
                      -I../../mingw/gtk+-bundle_2.16.6-20100912_win32/include/glib-2.0     \
                      -I../../mingw/gtk+-bundle_2.16.6-20100912_win32/lib/glib-2.0/include \
                      -I../../mingw/include                  \
                      -I$(GDALPATH)ogr                       \
                      -I$(GDALPATH)port                      \
                      -I$(GDALPATH)gcore                     \
                      -I$(GDALPATH)frmts/iso8211/            \
                      -DS52_USE_DOTPITCH                     \
                      -DS52_USE_FTGL                         \
                      -DS52_USE_OPENGL_VBO                   \
                      -DS52_USE_GLIB2                        \
                      -DS52_USE_PROJ                         \
                      -DS52_USE_OGR_FILECOLLECTOR            \
                      -DS52_USE_LOG                          \
                      -DS52_DEBUG $(DBG)

s52eglw32 : GDALPATH = ../../../gdal/gdal-1.7.2-mingw
s52eglw32 : CFLAGS   = -mms-bitfields                         \
                      -I../../mingw/gtk+-bundle_2.16.6-20100912_win32/include/glib-2.0     \
                      -I../../mingw/gtk+-bundle_2.16.6-20100912_win32/lib/glib-2.0/include \
                      -I../../mingw/include                   \
                      -I$(GDALPATH)/ogr                       \
                      -I$(GDALPATH)/port                      \
                      -I$(GDALPATH)/gcore                     \
                      -I$(GDALPATH)/frmts/iso8211/            \
                      -I$(GDALPATH)/alg                       \
                  -I./lib/freetype-gl            \
                  -I./lib/tesselator             \
                  -I./lib/parson                 \
                  -DS52_USE_PROJ                 \
                  -DS52_USE_GLIB2                \
                  -DS52_USE_DOTPITCH             \
                  -DS52_USE_OPENGL_VBO           \
                  -DS52_USE_EGL                  \
                  -DS52_USE_GLES2                \
                  -DS52_USE_FREETYPE_GL          \
                  -DS52_USE_OGR_FILECOLLECTOR    \
                  -DS52_USE_SYM_VESSEL_DNGHL     \
                  -DS52_DEBUG $(DBG)


############### LIBS setup ##############################
#
#

LIBS   = `pkg-config  --libs glib-2.0 lcms ftgl glu gl` \
         `gdal-config --libs` -lproj                    \

s52clutter, s52clutter.js : LIBS = `pkg-config  --libs glib-2.0 lcms` \
                                   `gdal-config --libs`   -lGL -lGLU


s52glx : LIBS = `pkg-config  --libs glib-2.0 lcms` \
                `gdal-config --libs`               \
                -lGL -lGLU

#s52gtk3egl s52eglx: LIBS = `pkg-config  --libs glib-2.0 gio-2.0 lcms egl glu gl freetype2`
s52eglx s52gtk2egl s52gtk3egl: LIBS = `pkg-config  --libs glib-2.0 gio-2.0 lcms egl glesv2 freetype2` \
                                      `gdal-config --libs` -lproj

# check this; gv use glib-1 S52 use glib-2
s52gv  : LIBS = `glib-config --libs`               \
                `gdal-config --libs`               \
                `gtk-config  --libs`               \
                -llcms

s52gv2 : LIBS = `pkg-config  --libs glib-2.0 lcms` \
                `gdal-config --libs`               \
                 -lGL -lGLU  $(GV2LIBS)


s52eglios : LIBS = /home/aaron/iOS_lib
# this goes with the -DS52_USE_PROJ flags
#LIBS += -lproj


s52glx        : libS52.so    test/s52glx
s52eglx       : libS52.so    test/s52eglx
s52gtk2egl    : libS52.so    test/s52gtk2egl
s52gtk3egl    : libS52.so    test/s52gtk3egl
s52eglarm     : $(S52DROIDLIB)/libS52.a     test/s52eglarm
s52eglios     : libS52.a     test/s52eglios
s52gv         : libS52gv.so  test/s52gv
s52gv2        : libS52gv.so  test/s52gv2
s52gtk2       : libS52.so    test/s52gtk2
s52gtk2p      : $(OBJS_S52)  test/s52gtk2p  # static link
s52clutter    : libS52.so    test/s52clutter
s52clutter.js : libS52.so    test/s52clutter.js
s52qt4        : libS52.so    test/s52qt4
s52win32      : libS52.dll   test/s52win32 s52win32fini
#s52win32gps  : libS52.dll   test/s52win32gps s52win32fini
s52eglw32     : libS52.dll   test/s52eglw32
s52gtk2gps    : libS52.so    test/s52gtk2gps


#S52raz-3.2.rle: S52raz.s
S52raz-3.2.rle.o: S52raz.s
	$(CC) -c S52raz.s -o $@

%.o: %.c %.h S52.h
	$(CC) $(CFLAGS) -c $< -o $@

./lib/tesselator/%.o: ./lib/tesselator/%.c
	$(CC) $(CFLAGS) -c $< -o $@

./lib/freetype-gl/%.o: ./lib/freetype-gl/%.c
	$(CC) $(CFLAGS) -c $< -o $@

./lib/parson/%.o: ./lib/parson/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(S52DROIDLIB)/libS52.a: $(OBJS_S52) $(OBJS_TESS) $(OBJS_FREETYPE_GL) $(OBJ_PARSON) tags
	$(AR) r   $(S52DROIDLIB)/libS52.a $(OBJS_S52) $(OBJS_FREETYPE_GL) $(OBJS_TESS) $(OBJ_PARSON)

$(S52IOSLIB)/libS52.a: $(OBJS_S52) $(OBJS_TESS) $(OBJS_FREETYPE_GL) $(OBJ_PARSON) tags
	$(AR) r   $(S52IOSLIB)/libS52.a $(OBJS_S52) $(OBJS_FREETYPE_GL) $(OBJS_TESS) $(OBJ_PARSON)

libS52.so: $(OBJS_S52) $(OBJS_TESS) $(OBJS_FREETYPE_GL) $(OBJ_PARSON) tags
	$(CXX) -rdynamic -shared $(OBJS_S52) $(OBJS_FREETYPE_GL) $(OBJS_TESS) $(OBJ_PARSON) $(LIBS) -o $@

libS52gv.so: $(OBJS_S52) $(OBJS_GV)
	$(CXX) -shared $(OBJS_S52) $(OBJS_GV) $(LIBS) -o libS52.so

#-static-libgcc
#	$(LIBWIN32PATH)/libftgl.a -lfreetype6
s52win32 s52eglw32 : GTKPATH = $(HOME)/dev/gis/openev-cvs/mingw/gtk+-bundle_2.16.6-20100912_win32/bin
s52win32 s52eglw32 : LIBS    = $(LIBWIN32PATH)/libproj.a     \
                               $(LIBWIN32PATH)/libftgl.a     \
                               $(LIBWIN32PATH)/libgdal-1.dll \
                               $(LIBWIN32PATH)/liblcms-1.dll

#libS52.dll: $(OBJS_S52)
#	$(MINGW)objcopy --redefine-sym S52raz=_S52raz                     \
#	--redefine-sym S52razLen=_S52razLen S52raz-3.2.rle.o S52raz-3.2.rle.o
#	 $(MINGW)g++ -g -mms-bitfields -O0 -Wall  -shared -Wl,--add-stdcall-alias $(OBJS_S52) \
#	 $(LIBS)                               \
#	-L$(GTKPATH) -lglib-2.0-0 -lfreetype6  \
#	-lopengl32 -lglu32 -o $@

libS52.dll: $(OBJS_S52) $(OBJS_FREETYPE_GL) $(OBJS_TESS) $(OBJ_PARSON)
	$(MINGW)objcopy --redefine-sym S52raz=_S52raz                         \
	--redefine-sym S52razLen=_S52razLen S52raz-3.2.rle.o S52raz-3.2.rle.o
	 $(MINGW)g++ -g -mms-bitfields -O0 -Wall  -shared -Wl,--add-stdcall-alias \
	 $(OBJS_S52) $(OBJS_FREETYPE_GL) $(OBJS_TESS) $(OBJ_PARSON)               \
	 $(LIBS)                                                                  \
	-L$(GTKPATH) -lglib-2.0-0 -lfreetype6                                     \
	$(LIBWIN32PATH)/libEGL.lib $(LIBWIN32PATH)/libGLESv2.lib -o $@


############### Test ##############################
#
#

test/s52glx:
	(cd test; make s52glx)

test/s52eglx:
	(cd test; make s52eglx)

test/s52gtk2egl:
	(cd test; make s52gtk2egl)

test/s52gtk3egl:
	(cd test; make s52gtk3egl)

test/s52eglarm:
	(cd test/android; make)

test/s52gv:
	(cd test; make s52gv)

test/s52gv2:
	(cd test; make s52gv2)

test/s52gtk2:
	(cd test; make s52gtk2)

test/s52gtk2gps:
	(cd test; make s52gtk2gps)

test/s52clutter:
	 (cd test; make s52clutter)

test/s52clutter.js:
	 (cd test; make s52clutter.js)

test/s52gtk2p:
	(cd test; make s52gtk2p)

test/s52qt4:
	(cd test; make s52qt4)

test/s52win32:
	(cd test; make s52win32)

test/s52win32gps:
	(cd test; make s52win32gps)

test/s52eglw32:
	(cd test; make s52eglw32)


s52win32fini:
	$(MINGW)strip libS52.dll

# NOTE: libS52 need to know where is _gv python wrapper is
# when using openev.py because we have du jump back to it
# to get to the handle of gvProperty of layers
#../../openev/pymod/_gvmodule.so


############### Utils ##############################
#
#

clean:
	rm -f *.o tags openc.* *~ *.so *.dll err.txt                \
	./lib/tesselator/*.o ./lib/freetype-gl/*.o ./lib/parson/*.o
	(cd test; make clean)

distclean: clean
	rm -f test/android/dist/system/lib/libS52.a
	(cd test; make distclean)

install:
	install libS52.so `gdal-config --prefix`/lib

uninstall:
	rm -f `gdal-config --prefix`/lib/libS52.so

tar: backup
backup: clean
	(cd ..; tar cvf openc.tar S52)
	bzip2 openc.tar

tags:
	$(TAGS) *.c *.h

err.txt: *.c *.h
	cppcheck --enable=all $(DEFS) *.c 2> err.txt



# git:
#   git init (one time)
#   git add <file>  (ex README)
#   git commit -m "new"
#   git remote add origin https://github.com/sduclos/S52.git (one time !)
#   git push -u origin master (sync local .git with github !)

# note on working with git
#
# SD 2012OCT06

# 0 - init (do once)
# Assigns the original repo to a 'remote' called "upstream"
# $ git remote add upstream https://github.com/rikulo/rikulo


# --- normal flow ---

# 1 - sync .git with official git
# Fetches any new changes from the original repo
# Pulls in changes not present in your local repository,
# without modifying your files
# SD this will sync LOCAL .git with official Rikulo
# $ git fetch upstream

# 2 - sync LOCAL files with .git
# Merges any changes fetched into your working files
#
# $ git merge upstream/master


# 3 - sync .git with sduclos git on GitHub
# Pushes commits (.git) to your remote repo stored on GitHub
# $ git push origin master

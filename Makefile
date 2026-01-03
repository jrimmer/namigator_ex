# Makefile
PRIV_DIR = priv
NIF_SO = $(PRIV_DIR)/namigator_nif.so

# Erlang include path
ERL_INCLUDE = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Source files
NIF_SRC = c_src/namigator_nif.cpp

NAMIGATOR_SRCS = \
	c_src/namigator/pathfind/Map.cpp \
	c_src/namigator/pathfind/Tile.cpp \
	c_src/namigator/pathfind/BVH.cpp \
	c_src/namigator/pathfind/TemporaryObstacle.cpp \
	c_src/namigator/utility/AABBTree.cpp \
	c_src/namigator/utility/BinaryStream.cpp \
	c_src/namigator/utility/BoundingBox.cpp \
	c_src/namigator/utility/MathHelper.cpp \
	c_src/namigator/utility/Matrix.cpp \
	c_src/namigator/utility/Quaternion.cpp \
	c_src/namigator/utility/Ray.cpp \
	c_src/namigator/utility/String.cpp \
	c_src/namigator/utility/Vector.cpp

DETOUR_SRCS = \
	c_src/recastnavigation/Detour/Source/DetourAlloc.cpp \
	c_src/recastnavigation/Detour/Source/DetourAssert.cpp \
	c_src/recastnavigation/Detour/Source/DetourCommon.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMesh.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMeshBuilder.cpp \
	c_src/recastnavigation/Detour/Source/DetourNavMeshQuery.cpp \
	c_src/recastnavigation/Detour/Source/DetourNode.cpp

RECAST_SRCS = \
	c_src/recastnavigation/Recast/Source/Recast.cpp \
	c_src/recastnavigation/Recast/Source/RecastAlloc.cpp \
	c_src/recastnavigation/Recast/Source/RecastArea.cpp \
	c_src/recastnavigation/Recast/Source/RecastAssert.cpp \
	c_src/recastnavigation/Recast/Source/RecastContour.cpp \
	c_src/recastnavigation/Recast/Source/RecastFilter.cpp \
	c_src/recastnavigation/Recast/Source/RecastLayers.cpp \
	c_src/recastnavigation/Recast/Source/RecastMesh.cpp \
	c_src/recastnavigation/Recast/Source/RecastMeshDetail.cpp \
	c_src/recastnavigation/Recast/Source/RecastRasterization.cpp \
	c_src/recastnavigation/Recast/Source/RecastRegion.cpp

ALL_SRCS = $(NIF_SRC) $(NAMIGATOR_SRCS) $(DETOUR_SRCS) $(RECAST_SRCS)
ALL_OBJS = $(ALL_SRCS:.cpp=.o)

# Compiler flags
CXX = c++
CXXFLAGS = -O3 -std=c++17 -fPIC -Wall -DDT_POLYREF64
CXXFLAGS += -I$(ERL_INCLUDE)
CXXFLAGS += -Ic_src
CXXFLAGS += -Ic_src/namigator
CXXFLAGS += -Ic_src/recastnavigation/Detour/Include
CXXFLAGS += -Ic_src/recastnavigation/Recast/Include

# Platform-specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS = -undefined dynamic_lookup -dynamiclib
else
	LDFLAGS = -shared
endif

.PHONY: all clean

all: $(NIF_SO)

$(NIF_SO): $(ALL_OBJS)
	@mkdir -p $(PRIV_DIR)
	$(CXX) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -f $(NIF_SO) $(ALL_OBJS)

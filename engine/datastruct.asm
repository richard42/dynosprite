*********************************************************************************
* DynoSprite - datastruct.asm
* Copyright (c) 2013-2014, Richard Goedeken
* All rights reserved.
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* * Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
* 
* * Redistributions in binary form must reproduce the above copyright notice,
*   this list of conditions and the following disclaimer in the documentation
*   and/or other materials provided with the distribution.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*********************************************************************************

* Data files layouts:
* -------------------
* - Object/Sprite file (OBJECTS.DAT)
*   - For each Group:
*     - Sprite descriptor table (data size in bytes replaces Ptr entries)
*     - Object descriptor table (offset from code block start replaces Ptr entries)
*     - Compressed block: For each sprite:
*       - Code: DrawLeft, DrawRight, Erase           (stored in Sprite Code pages)
*     - Compressed block: For each object:
*       - Code: Init, Update, Reactivate, Draw       (stored in Level/Object Code page)
* - Tilesets (TILES.DAT)
*   - For each tileset:
*     - palette (32 bytes, 16 CMP + 16 RGB)
*     - compressed collision table (raw size is one byte per tile)
*     - compressed tile data (raw size is 128 bytes per tile)
*     - compressed collision mask data (raw size is 128 bytes per mask)
* - Level-specific data (LEVELS.DAT)
*   - For each level:
*     - Level Directory:
*       - OIT length                 (short)
*       - Raw code length            (short)
*       - Compressed code length     (short)
*       - Compressed tilemap length  (short)
*       - Function offsets
*         - InitializeLevel          (short)
*         - CalculateBkgrndNewXY     (short)
*     - Object initialization table                  (discarded after use)
*     - Compressed Code Block                        (stored in Level/Object Code page)
*     - Compressed Background tilemap                (stored in Tilemap pages)
* - Sound Waveforms (SOUNDS.DAT)
*   - For each waveform:
*     - Compressed 8-bit audio data
* - Splash image data (IMAGES.DAT)
*   - For each splash image:
*     - palette (32 bytes, 16 CMP + 16 RGB)
*     - Color index for: background, foreground, progress bar (3 bytes)
*     - compressed image data

* Game Data Directories layouts
* - loaded with DECB game executable at $E00, before dynamic heap
* ----------------------------------------------------------------------------------------------
* - Object Data File directory:
*     - Total # of groups                          (char)
*     - For each Group:
*       - group number                             (char)
*       - size on disk in bytes                    (short)
*       - object code raw size in bytes            (short)
*       - compressed sprite code block bytes       (short)
*       - compressed object code block bytes       (short)
*       - number of sprites                        (char)
*       - number of objects                        (char)
* - Tileset Data File directory
*   - Total # of tilesets:                         (char)
*   - For each tileset:
*     - tileset number                             (char)
*     - total number of tiles                      (char)
*     - total number of collision masks            (char)
*     - compressed tile data size in bytes         (short)
* - Level directory
*   - Total # of levels
*   - For each level:
*     - level number                               (char)
*     - pointers to name,description of level      (2*short)
*     - size on disk in bytes                      (short)
*     - number of sprite/object groups to load     (char)
*     - pointer to group number list to load       (short)
*     - Current Object Table size                  (char)
*     - number of objects to initialize            (char)
*     - tileset number to load                     (char)
*     - width and height of background tilemap     (short*2)
*     - background tilemap starting position       (short*2)
* - Sound Data File directory
*   - Total # of sound waveforms                   (char)
*   - For each waveform:
*     - Uncompressed size                          (short)
*     - Compressed size / starting address         (short)
* - Image Data File directory
*   - Total # of images                            (char)
*   - For each image:
*     - width (in bytes) and height                (char*2)
*     - Compressed size                            (short)

* -----------------------------------------------------------------------------
* -- Sprite Group Table
* -----------------------------------------------------------------------------
* The Sprite Group Table binds together all of the sprite groups for a particular level.
* Each sprite group has one entry in this table.  Each entry is 10-bytes, formatted as:
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*     groupIdx        0        1   Global group index number for this sprite/object group
*      spCount        1        1   Number of sprites in this group
*      obCount        2        1   Number of objects in this group
*         res1        3        1   N/A
*      sprites        4        2   Pointer to Sprite Descriptor table for this group
*      objects        6        2   Pointer to Object Descriptor table for this group
*      rowcrop        8        2   Pointer to Sprite Rowcrop table for this group, or NULL

SGT         STRUCT
groupIdx                rmb     1
spCount                 rmb     1
obCount                 rmb     1
res1                    rmb     1
sprites                 rmd     1
objects                 rmd     1
rowcrop                 rmd     1
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Sprite Descriptor Table
* -----------------------------------------------------------------------------
* Each Sprite object in a group has a 16-byte descriptor, formatted as follows:
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*        width        0        1   Width of sprite
*       height        1        1   Height of sprite
*      offsetX        2        1   Offset in bytes to add to global X coordinate to draw sprite at hotspot
*      offsetY        3        1   Offset in lines to add to global Y coordinate to draw sprite at hotspot
*       cpLeft        4        1   virtual page number for drawLeft function
*      cpRight        5        1   virtual page number for drawRight function or 0
*      cpErase        6        1   virtual page number for erase function
*   storeBytes        7        2   Number of bytes to reserve for storing background pixels
*     drawLeft        9        2   Pointer to ASM function for storing/drawing
*    drawRight       11        2   Pointer to ASM function for storing/drawing or NULL
*        erase       13        2   Pointer to ASM function for erasing sprite
*         res1       15        1   Reserved

SDT         STRUCT
width                   rmb     1
height                  rmb     1
offsetX                 rmb     1
offsetY                 rmb     1
cpLeft                  rmb     1
cpRight                 rmb     1
cpErase                 rmb     1
storeBytes              rmd     1
drawLeft                rmd     1
drawRight               rmd     1
erase                   rmd     1
res1                    rmb     1
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Sprite Rowcrop Table
* -----------------------------------------------------------------------------
* If any Sprite in the group was created with RowPointerArray=True, then the group shall contain a
* Sprite Rowcrop Table with one entry for each Sprite.  This is a 16-byte descriptor, formatted as follows:
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*   drawLByRow        0        2
*  L_YoffByRow        2        2
*   drawRByRow        4        2
*  R_YoffByRow        6        2
*   eraseByRow        8        2
*  E_YoffByRow       10        2
*     reserved       12        4

ROW         STRUCT
drawLByRow              rmd     1
L_YOffByRow             rmd     1
drawRByRow              rmd     1
R_YOffByRow             rmd     1
eraseByRow              rmd     1
E_YoffByRow             rmd     1
res1                    rmd     2
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Object Descriptor Table
* -----------------------------------------------------------------------------
* The Object Descriptor Table contains descriptive parameters for each object in a sprite group.
* Each element in this table is 16 bytes:
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*     dataSize        0        1   Number of bytes required to store state data for this object
*     drawType        1        1   0=Custom func, 1=standard sprite no rowcrop, 2=sprite w/ rowcrop
*     initSize        2        1   Number of bytes in object stream to reserve for initializing this object
*         res1        3        1   N/A
*         init        4        2   Pointer to ASM function for initializing object
*   reactivate        6        2   Pointer to ASM function for determining if object should be reactivated
*       update        8        2   Pointer to ASM function for updating state of object
*         draw       10        2   Pointer to custom ASM function for drawing object
*         res2       12        4   N/A

ODT         STRUCT
dataSize                rmb     1
drawType                rmb     1
initSize                rmb     1
res1                    rmb     1
init                    rmd     1
reactivate              rmd     1
update                  rmd     1
draw                    rmd     1
vpageAddr               rmd     1
res2                    rmd     2
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Current Object Table
* -----------------------------------------------------------------------------
* The Current Object Table is part of the level logic.  Each element in this table is 16 bytes:
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*     groupIdx        0        1   Group number of this object
*    objectIdx        1        1   Object number within group
*       active        2        1   bit 0 = update active, bit 1 = draw active
*     reserved        3        1   N/A
*      globalX        4        2   X Position of this object relative to world origin, in pixels
*      globalY        6        2   Y Position of this object relative to world origin, in pixels
*     statePtr        8        2   Pointer to state data for this object
*       odtPtr       10        2   Pointer to Object Descriptor Table for this object
*       sprPtr       12        2   Pointer to beginning of Sprite Descriptor Table for this object's group
*       rowPtr       14        2   Pointer to beginning of Sprite Rowcrop Table for this object's group

COB         STRUCT
groupIdx                rmb     1
objectIdx               rmb     1
active                  rmb     1
res1                    rmb     1
globalX                 rmd     1
globalY                 rmd     1
statePtr                rmd     1
odtPtr                  rmd     1
sprPtr                  rmd     1
rowPtr                  rmd     1
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Sprite Erase Data Heap
* -----------------------------------------------------------------------------
* The Sprite Erase Data Heap contains all of the bytes containing pixels which were overwritten
* by sprites in a frame buffer.  There are 2 separate data heaps in an 8k page (one for the
* first screen buffer pair, and another for the second).  Each heap is 4k in size.
*
* Layout for Mode 0 (No Rowcrop):
*
* Element Name | Offset | Length | Meaning
*-----------------------------------------
*                     0        2   Pointer to erase function for this sprite
*                     2        N   Background pixel bytes
*                   N+2        2   N (Number of background pixel bytes stored)
*                   N+4        1   Code page (virtual handle) for erase function for this sprite
*                   N+5        1   8k page number for screen background pixels
*                   N+6        2   Start offset for screen background pixels (graphics window $8000-$BFFF)
*                   N+8        1   Mode number (0 for no rowcrop, or 1 for rowcrop)
*

* -----------------------------------------------------------------------------
* -- Game Data Directories
* -----------------------------------------------------------------------------
* These data tables are created by the various python script tools as part of the Dynosprite build
* process. They are included in main.asm, and loaded with DECB game executable at $E00, just before
* the dynamic heap.  They are mainly used in loader.asm.

*Gamedir_Levels
*
GDL         STRUCT
LvlNum                  rmb     1
NamePtr                 rmb     2
DescPtr                 rmb     2
DiskSize                rmb     2
NumGroups               rmb     1
GroupsPtr               rmb     2
COTSize                 rmb     1
InitObjs                rmb     1
TilesetNum              rmb     1
TilemapWidth            rmb     2
TilemapHeight           rmb     2
BkStartX                rmb     2
BkStartY                rmb     2
            ENDSTRUCT

*Gamedir_Objects
*
GDO         STRUCT
GrpNum                  rmb     1
DiskSize                rmb     2
ObjCodeSize             rmb     2
CompSpriteCodeSize      rmb     2
CompObjCodeSize         rmb     2
NumSprites              rmb     1
NumObjects              rmb     1
            ENDSTRUCT

*Gamedir_Tiles
*
GDT         STRUCT
TilesetNum              rmb     1
NumTiles                rmb     1
NumMasks                rmb     1
DiskSize                rmb     2
            ENDSTRUCT

*Gamedir_Sounds
*
GDS         STRUCT
SizeUncomp              rmb     2
SizeComp                rmb     2
            ENDSTRUCT

*Gamedir_Images
*
GDI         STRUCT
WidthBytes              rmb     1
HeightRows              rmb     1
SizeComp                rmb     2
            ENDSTRUCT



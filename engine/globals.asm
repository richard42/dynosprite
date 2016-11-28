*********************************************************************************
* DynoSprite - globals.asm
* Copyright (c) 2013, Richard Goedeken
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

                        org     $2000

* -----------------------------------------------------------------------------
* -- Memory Manager
* -----------------------------------------------------------------------------

***********************************************************
* Virtual handle table (64 bytes)
* $00 - $3F: mapped to corresponding 512k physical memory page
* $FF: unused handle
*
* See top of memory.asm for the virtual handle assignments
* 
MemMgr_VirtualTable     zmb     64

***********************************************************
* Other memory manager variables

MemMgr_GfxAperStart     zmb     1       * the graphics aperature start/end values are physical block numbers
MemMgr_GfxAperEnd       zmb     1
MemMgr_HeapEndPtr       zmd     1

* -----------------------------------------------------------------------------
* -- Graphics
* -----------------------------------------------------------------------------
* The background consists of 16x16 tiles, with a tilemap giving the block numbers for all blocks in the virtual
* playfield.  The displayed video screen (a small subset of the entire playfield) can be scrolled with respect
* to the background by setting the BkgrndStartXY values.
*
* The 256-byte wide GIME feature is used, with the 16-bit color mode.  The width of the active display is
* 160 bytes, and it is centered within each 256-byte row.  The graphics aperature covers four screen areas.
* Each screen area is 256 bytes wide and 224 lines long (seven 8k pages).  The first 2 screen areas are the
* even/odd aligned copies of Buffer 0, and the second 2 screen areas are the even/odd aligned copies of
* Buffer 1.  These two screen pairs (Buffer 0 and Buffer 1) are used for double buffering.  Within each
* pair, the Even (first) screen area is naturally aligned so that tile X edges are 2-byte aligned. The
* Odd (second) screen area contains the screen data shifted to the left by one byte.  So the pixel pair at
* byte address N in the Odd screen is the same as the pair at byte address N+1 in the Even screen. 
* This is used to allow horizontal scrolling in units of 1 byte (2 pixels).
*

Gfx_BkgrndBlockCount    zmb     1       * number of background 16x16 blocks defined in this level
Gfx_BkgrndBlockPages    zmb     1       * number of allocated 8k pages for tiles

Gfx_BkgrndMapPages      zmb     1
Gfx_BkgrndMapWidth      zmd     1
Gfx_BkgrndMapHeight     zmd     1
Gfx_BkgrndStartXMax     zmd     1
Gfx_BkgrndStartYMax     zmd     1

Gfx_CurrentFieldCount   zmb     1       * used by IRQ handler to track the 60hz field rate
Gfx_LastRenderedFrame   zmb     1       * these next 2 counters are used for vertical retrace sync and double buffering
Gfx_DisplayedFrame      zmb     1
Gfx_RenderingFrameX4    zmb     1       * cached value used in several places: (1 - (LastRenderedFrame & 1)) * 4

Gfx_BkgrndStartXYList   zmd     4       * X,Y (word) start pixel byte location for each buffer pair
Gfx_BkgrndPhyAddrList   zmd     4       * Page (byte), offset (word) of Origin (0,0) pixel in each buffer pair

Gfx_BkgrndLastX         zmd     1       * X,Y coordinates of last rendered buffer pair
Gfx_BkgrndLastY         zmd     1
Gfx_BkgrndRedrawOldX    zmd     1       * Old X,Y coordinates of buffer pair which is being redrawn
Gfx_BkgrndRedrawOldY    zmd     1
Gfx_BkgrndNewX          zmd     1       * New X,Y coordinates of buffer pair which is being redrawn
Gfx_BkgrndNewY          zmd     1
Gfx_BkgrndNewX2         zmd     1       * New X coordinate in pixels
Gfx_BkgrndXFrac         zmb     1       * each background coordinate has 8 bit of fraction
Gfx_BkgrndYFrac         zmb     1

Gfx_DrawScreenPage      zmb     1       * cache starting physical address of new screen being drawn
Gfx_DrawScreenOffset    zmd     1

Gfx_SpriteErasePtrs     zmd     4       * (Start,End) pointers for each 4k erase pixel data buffer heap
Gfx_SpriteErasePtrPtr   zmd     1       * Pointer to Gfx_SpriteErasePtrs for frame currently being drawn

Gfx_NumSpriteGroups     zmb     1       * number of active sprite/object groups loaded
Gfx_SpriteGroupsPtr     zmd     1       * pointer to Sprite Group Table

Gfx_MonitorIsRGB        zmb     1       * selects which palette to write to the hardware

* -----------------------------------------------------------------------------
* -- Object
* -----------------------------------------------------------------------------

Obj_MotionFactor        zmb     1       * number of 60hz fields elapsed since last redraw, minus two

Obj_NumCurrent          zmb     1       * number of objects in Current Object Table
Obj_CurrentTablePtr     zmd     1
Obj_StateDataPtr        zmd     1

* -----------------------------------------------------------------------------
* -- Input
* -----------------------------------------------------------------------------

Input_UseKeyboard       zmb     1

Input_JoystickX         zmb     1       * these values are between 0 and 63
Input_JoystickY         zmb     1
Input_Buttons           zmb     1

Joy1Button1             equ     1
Joy2Button1             equ     2
Joy1Button2             equ     4
Joy2Button2             equ     8

Input_JoyButtonMask     zmb     1
Input_KeyMatrix         zmb     8       * most recent raw KB matrix state
Input_KeyMatrixDB       zmb     8       * these are debounced and one-shot keypress bitmaps
Input_NumPressedKeys    zmb     1
Input_PressedKeyCodes   zmb     8

* -----------------------------------------------------------------------------
* -- Sound
* -----------------------------------------------------------------------------

AudioSamplingRate       EQU     6000

Sound_OutputMode        zmb     1       * -1=no sound, 0=internal 6-bit DAC, 1=Orchestra-90

Sound_NumWavePages      zmb     1
Sound_WavePageEndPtrs   zmd     8

Sound_ChannelsPlaying   zmb     1       * bit 0 == channel 0, bit 1 == channel 1
Sound_Chan0VPage        zmb     1
Sound_Chan0Ptr          zmd     1
Sound_Chan0End          zmd     1
Sound_Chan1VPage        zmb     1
Sound_Chan1Ptr          zmd     1
Sound_Chan1End          zmd     1

* -----------------------------------------------------------------------------
* -- Loader
* -----------------------------------------------------------------------------

Ldr_CurLevel            zmb     1
*Level data directory
Ldr_LevelDataDir
Ldr_LDD.LengthOIT       zmb     2
Ldr_LDD.LengthCodeRaw   zmb     2
Ldr_LDD.LengthCodeComp  zmb     2
Ldr_LDD.LengthMapComp   zmb     2
Ldr_LDD.PtrInitLevel    zmb     2
Ldr_LDD.PtrCalcBkgrnd   zmb     2

* -----------------------------------------------------------------------------
* -- Demo
* -----------------------------------------------------------------------------

Demo_ScreenDeltaX88     zmd     1       * 8.8 fixed-point difference value of screen start position between frames
Demo_ScreenDeltaY88     zmd     1

* -----------------------------------------------------------------------------
* -- locals - these are for speed, and should only be used by the owning function
* -----------------------------------------------------------------------------

* locals for Input_ReadJoyAxis
in_MinValue             zmb     1
in_MaxValue             zmb     1

* locals for Gfx_UpdateBackground
gfx_DeltaXBlks          zmb     1

* inputs to Gfx_RedrawRect
RR_RectBlocksX          zmb     1
RR_RectRowsY            zmb     1
RR_StartBlkX            zmb     2
RR_StartRowY            zmb     2

* locals for Gfx_RedrawRect
rr_TempMulHi            zmb     1
rr_TilemapPage          zmb     1
rr_ScreenPage           zmb     1
rr_BlocksLeftX          zmb     1
rr_RowsLeftY            zmb     1
rr_RowsLeftInBlk        zmb     1
rr_RowsToDraw           zmb     1
rr_TexRowOffset         zmb     1

* locals for Gfx_SpriteDrawSimple
gfx_DrawOffsetX         zmb     1
gfx_DrawOffsetY         zmb     1
gfx_DrawSpritePage      zmb     1
gfx_DrawSpriteOffset    zmb     2
gfx_DrawLeftOrRight     zmb     1

* -----------------------------------------------------------------------------
* -- End of Direct Page - make sure it all fits
* -----------------------------------------------------------------------------

DPEnd                   equ     *
 IFGT *-$2100
    Error "In globals.asm: direct page data is bigger than 256 bytes!"
 ENDC
                        org     $2100

***********************************************************
* Sound: primary page buffer

Sound_PageBuffer        rmb     256     * warning: this buffer must be aligned on 256-byte boundary

***********************************************************
* Physical Memory Map (64 bytes)
* $00 - $3F: mapped to corresponding virtual handle
* $FF: unused
* $FE: fixed (unmoveable)
* $FD: part of current graphics aperature

MemMgr_PhysicalMap      zmb     64

***********************************************************
* Graphics: Palettes

Gfx_Palette_CMP_RGB     rmb     32
Gfx_PalIdx_BKColor      rmb     1       * the 4-bit color value is in both nybbles of these bytes
Gfx_PalIdx_FGColor      rmb     1
Gfx_PalIdx_BarColor     rmb     1

***********************************************************
* Disk file data: here we store one cached file data sector
* and one cached directory sector

Disk_DirSector          rmb     256
Disk_CacheSector        rmb     256

 IFDEF DEBUG
Disk_FileIsOpen         fcb     0
Disk_FileAtEnd          fcb     0
 ENDC
Disk_DirSectorNum       fcb     $ff
Disk_CachedTrackIdx     fcb     $ff
Disk_CachedSectorIdx    fcb     $ff
Disk_FileCurGranule     rmb     1
Disk_FileCurTrack       rmb     1
Disk_FileCurSector      rmb     1
Disk_FileCurByte        rmb     1
Disk_FileGranulesLeft   rmb     1
Disk_FileBytesInCurGran rmd     1
Disk_FileBytesInLastSec rmd     1
Disk_ProgressCallback   rmd     1

Disk_FAT                rmb     68

***********************************************************
* Graphics: Image fadein/fadeout random tables

Img_Random161           fcb     10,119,12,76,151,41,11,98,55,31,21,19,153,5,127,139,39,50,133,107,90,0,108,93,69,59,134,88,113,63,86,34,154,152,145,100,91,61,147,160,124,38,126,89,80,74,53,66,81,62,22,9,85,82,20,65,116,114,120,73,157,136,51,68,118,125,28,123,158,36,60,37,16,64,156,103,146,44,97,56,115,148,104,105,92,40,13,30,144,87,141,71,54,111,155,78,6,25,143,112,23,99,122,79,77,52,102,3,58,2,17,43,67,49,15,33,131,106,27,57,95,140,101,1,32,45,159,35,96,72,75,4,135,138,14,46,29,48,94,70,83,26,18,130,110,109,142,149,129,7,121,42,128,132,47,137,24,117,150,8,84
Img_Random200           fcb     154,113,57,130,163,17,86,168,108,37,79,94,69,192,118,31,173,136,36,23,52,131,170,12,99,102,159,47,194,82,158,93,13,139,83,22,148,68,142,123,112,160,198,92,183,166,132,42,18,73,60,50,76,8,164,10,134,48,167,127,182,66,43,100,26,64,32,6,185,62,165,34,157,59,162,171,109,110,140,0,39,138,184,121,126,35,114,1,147,56,149,117,55,21,74,105,54,5,87,41,169,28,61,45,187,116,103,16,177,137,3,172,175,199,186,67,120,27,176,29,156,107,189,143,33,14,70,72,97,63,193,190,38,106,46,7,40,124,24,115,96,161,81,95,30,153,119,111,141,144,90,174,188,71,151,104,181,9,80,20,51,133,75,85,191,146,128,197,84,145,2,180,195,155,49,77,101,98,58,89,44,19,11,122,15,129,78,135,53,91,88,25,4,178,125,65,196,152,150,179




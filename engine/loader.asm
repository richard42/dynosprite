*********************************************************************************
* DynoSprite - loader.asm
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

*Local Data
*
Ldr_ObjectFilename      fcc     'OBJECTS DAT'
Ldr_LevelFilename       fcc     'LEVELS  DAT'
Ldr_TileFilename        fcc     'TILES   DAT'
Ldr_SoundFilename       fcc     'SOUNDS  DAT'
Ldr_SkipSound           zmb     1
Ldr_LvlObjCodeEndPtr    zmb     2
Ldr_NumSpriteCodePages  zmb     1
Ldr_BkgrndMapSize       zmb     2
Ldr_SpritePageEndPtrs   zmb     2*MAX_SPRITE_CODE_PAGES
Ldr_SectorsToLoad       zmb     2
Ldr_ProgressBarPtr      zmb     2
Ldr_ProgressBarPage     zmb     1
Ldr_CurProgressSec      zmb     2
Ldr_CurProgressPct      zmb     1

***********************************************************
* Ldr_Jump_To_New_Level:
*   This function never returns.  It calls Ldr_Load_level, which jumps
*   directly to 'mainloop' after loading level data.
*
* - IN:      A = Level # to load
* - OUT:     This function never returns, it jumps to 'mainloop'
***********************************************************
*
Ldr_Jump_To_New_Level
            pshs        a
            * shut off sound, just in case it was playing
            jsr         System_DisableAudioInterrupt
            clr         <Sound_ChannelsPlaying
            * if we have a rendered but not yet displayed frame, wait until it gets displayed
            lda         <Gfx_LastRenderedFrame
            cmpa        <Gfx_DisplayedFrame
            beq         >
            sync
            * unload the level, fade out the current screen, and load the new one
!           jsr         Ldr_Unload_Level
            clra
            jsr         Img_FadeOut
            clra
            jsr         System_SetPaletteConst
            puls        a
            bra         Ldr_Load_Level

***********************************************************
* Ldr_Load_Level:
*   This function never returns.  It jumps directly to 'mainloop'
*   after loading level data.
*
* - IN:      A = Level # to load
* - OUT:     This function never returns, it jumps to 'mainloop'
***********************************************************
*
LoadMsg@                fcn     'Loading...'
*
Ldr_Load_Level
            sta         <Ldr_CurLevel           * Save new level number to load
            * get pointer to the Gamedir_Levels entry for the new level
            ldx         #Gamedir_Levels
            ldb         ,x+                     * Get total # of levels
FindLevel1@
            cmpa        GDL.LvlNum,x
            beq         FoundLevel1@
            leax        sizeof{GDL},x
            decb
            bne         FindLevel1@
            swi                                 * Error: level not found
FoundLevel1@
            * Initialize the graphics aperature, prior to allocating any virtual 8k blocks
            pshs        x
            ldy         GDL.BkStartY,x          * setup Gfx_BkgrndStartXYList
            ldx         GDL.BkStartX,x
            stx         <Gfx_BkgrndStartXYList
            sty         <Gfx_BkgrndStartXYList+2
            stx         <Gfx_BkgrndStartXYList+4
            sty         <Gfx_BkgrndStartXYList+6
            stx         <Gfx_BkgrndNewX         * set up NewX/Y and RedrawOldX/Y globals so 2nd frame will be drawn in correct place
            stx         <Gfx_BkgrndRedrawOldX
            sty         <Gfx_BkgrndNewY
            sty         <Gfx_BkgrndRedrawOldY
            jsr         Gfx_SetInitialAperature * Initialize graphics aperature
            * Set up double-buffering variables
            clr         <Gfx_CurrentFieldCount
            orcc        #$50                    * disable interrupts
            clr         <Gfx_LastRenderedFrame
            clr         <Gfx_DisplayedFrame
            andcc       #$AF                    * re-enable interrupts
            ldb         #4
            stb         <Gfx_RenderingFrameX4   * set back buffer to second pair
            ldx         #Gfx_BkgrndStartXYList  * set both physical addresses
            jsr         Gfx_UpdatePhyAddress
            ldx         #Gfx_BkgrndStartXYList+4
            jsr         Gfx_UpdatePhyAddress
            clrb
            jsr         System_SetVideoStart    * then set GIME video start address for correct buffer pair
            * take the current background color and save it for filling the front buffer in SMC down below
            lda         Gfx_PalIdx_BKColor
            sta         SetFrontBufBackground@+1
            * Load splash image (Image # is the same as Level #)
            * start by calculating the X position (centered)
            ldx         ,s
            lda         GDL.LvlNum,x
            sta         <LoadImageNum@+2,PCR
            ldb         #sizeof{GDI}
            mul
            addd        #Gamedir_Images+1
            tfr         d,x
            lda         #160
            suba        GDI.WidthBytes,x
            lsra
            pshs        a                       * store X coordinate to load splash image (in bytes)
            * next calculate the Y position
            lda         #200-64                 * screen is 200 lines tall, minus 64 rows (4 lines) for loading message
            suba        GDI.HeightRows,x        * minus height of splash image is the total available margin
            ldb         #256/3
            mul                                 * now divide by 3 -- A is the Y coordinate to load splash image
            tfr         a,b
            lslb                                * B = 2 * Margin
            addb        GDI.HeightRows,x        * B = starting Y coordinate of loading message
            * store the loading message Y coordinates
            stb         <TextLine1Y0@+1,PCR
            addb        #16
            stb         <TextLine2Y0@+1,PCR
            addb        #18
            stb         <TextLine3Y0@+1,PCR
            addb        #14
            stb         <TextLine4Y0@+1,PCR
            * load the image
LoadImageNum@
            ldu         #0                      * SMC: image number is set in code above
            puls        b                       * retrieve X coordinate in B
            jsr         Img_Load_Splash_Image
            * Draw loading text on screen
            clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
            ldy         ,s
            ldx         GDL.NamePtr,y
            jsr         Util_StrLen
            tfr         a,b
            negb
            addb        #40
            lslb
TextLine1Y0@
            lda         #68                     * SMC: Y coordinate is set in code above
            pshs        u
            jsr         Gfx_DrawTextLine_Back
            puls        u
            ldy         ,s
            ldx         GDL.DescPtr,y
            jsr         Util_StrLen
            tfr         a,b
            negb
            addb        #40
            lslb
TextLine2Y0@
            lda         #84                     * SMC: Y coordinate is set in code above
            jsr         Gfx_DrawTextLine_Back
            ldx         #LoadMsg@
            clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
TextLine4Y0@
            lda         #116                    * SMC: Y coordinate is set in code above
            ldb         #60
            jsr         Gfx_DrawTextLine_Back
            * draw a box for progress bar
TextLine3Y0@
            lda         #102                    * SMC: Y coordinate is set in code above
            ldb         #80-17
            jsr         Gfx_GetPixelAddress_Back
            leay        $4000,y
            sty         Ldr_ProgressBarPtr
            sta         $FFA2
            inca
            sta         $FFA3
            suba        #15                     * progress bar will be drawn on front buffer, not back
            sta         Ldr_ProgressBarPage
            pshs        y
            ldx         #12
            lda         Gfx_PalIdx_FGColor
            tfr         a,b
            anda        #$0f
            andb        #$f0
BoxLoop1@
            sta         ,y
            stb         33,y
            leay        256,y
            leax        -1,x
            bne         BoxLoop1@
            puls        y
            leay        1,y
            lda         Gfx_PalIdx_FGColor
            ldx         #32
BoxLoop2@
            sta         ,y
            sta         2816,y                  * +11 rows
            leay        1,y
            leax        -1,x
            bne         BoxLoop2@
            * clear front buffer and set the new palette, then fade in
SetFrontBufBackground@
            lda         #0                      * SMC: the color to fill front buffer is the old background color, written in code above
            jsr         Gfx_FillScreen_Front
            jsr         System_SetPaletteAuto
            lda         #0
            jsr         Img_FadeIn
            * Allocate 8k block to store Level and Object code, and map it to $6000
            lda         #VH_LVLOBJCODE
            jsr         MemMgr_AllocateBlock
            stb         $FFA3
            ldd         #$6000
            std         Ldr_LvlObjCodeEndPtr
            * Start the SectorsToLoad calculation with the size of the level data
            ldx         ,s
            clra
            ldb         GDL.DiskSize,x
            INCREMENT_D
            std         Ldr_SectorsToLoad
            * Allocate page(s) for the Tilesets
            lda         GDL.TilesetNum,x
            ldx         #Gamedir_Tiles
            ldb         ,x+                     * get total # of tilesets
FindTileset1@
            cmpa        GDT.TilesetNum,x
            beq         FoundTileset1@
            leax        sizeof{GDT},x
            decb
            bne         FindTileset1@
            swi                                 * Error: tileset not found
FoundTileset1@
            ldd         Ldr_SectorsToLoad       * Continue SectorsToLoad calculation by adding tileset size
            addb        GDT.DiskSize,x
            adca        #0
            INCREMENT_D
            std         Ldr_SectorsToLoad
            ldb         GDT.NumTiles,x          * number of background pixel tiles in this set
            stb         <Gfx_BkgrndBlockCount
            ldb         GDT.NumMasks,x          * number of collision mask tiles in this set
            stb         <Gfx_BkgrndMaskCount
            clra
            addb        <Gfx_BkgrndBlockCount
            adca        #0
            lsra                                * 64 tiles per page, so shift right by 6
            rorb
            lsrb
            lsrb
            lsrb
            lsrb
            lsrb
            incb                                * B is number of pages to allocate
            stb         <Gfx_BkgrndBlockPages
            * don't need to "clra" because it must be zero after "lsra" above
AllocTilesetPages@
            pshs        a
            adda        #VH_BKTILES
            jsr         MemMgr_AllocateBlock
            puls        a
            inca
            cmpa        <Gfx_BkgrndBlockPages
            bne         AllocTilesetPages@
            * Allocate pages for the tilemap
            ldx         ,s
            lda         GDL.TilemapWidth+1,x    * 16x8 multiply to get tilemap array size
            ldb         GDL.TilemapHeight+1,x
            mul
            tfr         d,y
            lda         GDL.TilemapWidth,x
            ldb         GDL.TilemapHeight+1,x
            mul
 IFDEF DEBUG
            tsta
            beq         >
            swi                                 * Error: tilemap is too large
 ENDC
!           tfr         b,a
            clrb
            ADD_D_TO_Y
            tfr         y,d
            std         Ldr_BkgrndMapSize
            lsra                                * pages for tilemap = (size >> (8+5)) + 1
            lsra
            lsra
            lsra
            lsra
            inca                                * A is number of pages to allocate
            sta         <Gfx_BkgrndMapPages
            clra
AllocTilemapPages@
            pshs        a
            adda        #VH_BKMAP
            jsr         MemMgr_AllocateBlock
            puls        a
            inca
            cmpa        <Gfx_BkgrndMapPages
            bne         AllocTilemapPages@
            * Continue the SectorsToLoad calculation by adding the size of the sprite/object groups
            ldx         ,s
            lda         GDL.NumGroups,x         * Number of groups to load
            ldu         GDL.GroupsPtr,x         * Pointer to list of group numbers to load
            ldy         #Gamedir_Objects
            ldx         Ldr_SectorsToLoad
            ldb         ,y+                     * Total number of sprite/object groups in directory
FindGroup0@
            pshs        a,b
            ldb         GDO.GrpNum,y            * next group # in the directory
            cmpb        ,u                      * should we load it?
            beq         NeedGroup@
            puls        a,b
            leay        sizeof{GDO},y           * advance to next group in directory
            decb
            bne         FindGroup0@
            swi                                 * Error: couldnt find all groups in level's group load list
NeedGroup@
            clra
            ldb         GDO.DiskSize,y
            INCREMENT_D
            ADD_D_TO_X
            puls        a,b
            leau        1,u                     * next group number to load
            deca
            beq         AllGroupsFound@
            leay        sizeof{GDO},y           * advance to next group in directory
            decb
            bne         FindGroup0@
            swi                                 * Error: couldn't find all groups in level's group load list
AllGroupsFound@
            tst         Ldr_SkipSound           * do we need to load the sound data? (this data is only loaded once)
            bne         SkipSound1@
            tst         <Sound_OutputMode       * we also do not load audio data if Output Mode == No Sound
            bmi         SkipSound1@
            ldu         #Gamedir_Sounds
            clra
            ldb         ,u+                     * get number of waveforms in SOUNDS.DAT file
            beq         SkipSound1@
            tfr         d,y                     * Y is number of waveforms to load
            ldd         #0                      * D is size of compressed audio data to load in bytes
SoundSizeLoop@
 IFDEF DEBUG
            tst         1,u
            beq         >
            swi                                 * Error: uncompressed waveform length must be multiple of 256 bytes
 ENDC
!           addd        GDS.SizeComp,u
            leau        sizeof{GDS},u
            leay        -1,y
            bne         SoundSizeLoop@
            addd        #255
            tfr         a,b
            abx
SkipSound1@
            * Set up progress reporting variables
            stx         Ldr_SectorsToLoad
            clr         Ldr_CurProgressSec
            clr         Ldr_CurProgressSec+1
            clr         Ldr_CurProgressPct
            ldx         #Ldr_ProgressCallback
            jsr         Disk_SetProgressCallback
            * Set up environment for disk access
            jsr         System_EnterDiskMode    * This also maps the heap and game directories at $0000
            * open the LEVELS.DAT file
            ldx         #Ldr_LevelFilename
            jsr         Disk_FileOpen
            * seek thru this file to start of data block for current level
            ldx         #Gamedir_Levels+1
            lda         <Ldr_CurLevel
FindLevel2@
            cmpa        GDL.LvlNum,x
            beq         FoundLevel2@
            pshs        a,x
            ldd         GDL.DiskSize,x
            jsr         Disk_FileSeekForward
            puls        a,x
            leax        sizeof{GDL},x
            bra         FindLevel2@
FoundLevel2@
            * Allocate heap space for the Current Object Table
            ldx         ,s
            lda         GDL.InitObjs,x          * starting size of Current Object Table
            sta         <Obj_NumCurrent
            lda         GDL.COTSize,x           * Maximum size of Current Object Table for this level
            ldb         #sizeof{COB}
            mul
            jsr         MemMgr_Heap_Allocate
            stx         <Obj_CurrentTablePtr
            * setup the tilemap parameters
            ldx         ,s
            ldd         GDL.TilemapWidth,x
            std         <Gfx_BkgrndMapWidth
            ldd         GDL.TilemapHeight,x
            std         <Gfx_BkgrndMapHeight
            * load the level data directory
            ldy         #12                     * Level Data Directory is 12 bytes
            ldu         #Ldr_LevelDataDir
            jsr         Disk_FileRead
            * load the Object Initialization Table temporarily into the first Tileset page
            lda         #VH_BKTILES
            ldb         #2                      * map the page with OIT table into $4000
            jsr         MemMgr_MapBlock
            ldy         <Ldr_LDD.LengthOIT
            ldu         #$4000
            jsr         Disk_FileRead
            * load the Level code and set up the function pointers
            ldd         <Ldr_LDD.LengthCodeComp * D is the number of compressed bytes for level code
            jsr         Decomp_Init_Stream      * set up DEFLATE decoder
            ldy         <Ldr_LDD.LengthCodeRaw
            ldu         #$6000
            jsr         Decomp_Read_Stream
            ldd         #$6000
            addd        <Ldr_LDD.LengthCodeRaw
            std         Ldr_LvlObjCodeEndPtr    * update the end pointer
 IFDEF DEBUG
            tst         Decomp_OutReadDone      * make sure that we read everything from the uncompressed stream
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream
            * finally, load the tilemap data
            ldd         <Ldr_LDD.LengthMapComp  * D is the number of compressed bytes for tilemap
            jsr         Decomp_Init_Stream      * set up DEFLATE decoder
            lda         #VH_BKMAP
            ldy         Ldr_BkgrndMapSize
TilemapLoadLoop@
            pshs        a,y                     * map the next page into $4000
            ldb         #2
            jsr         MemMgr_MapBlock
            cmpy        #$2000
            bls         LastTilemapLoad@
            ldy         #$2000
            ldu         #$4000
            jsr         Decomp_Read_Stream
            puls        a,y
            leay        -$2000,y
            inca
            bra         TilemapLoadLoop@
LastTilemapLoad@
            leas        3,s
            ldu         #$4000
            jsr         Decomp_Read_Stream
 IFDEF DEBUG
            tst         Decomp_OutReadDone      * make sure that we read everything from the uncompressed stream
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream
            * close the LEVELS.DAT file
            jsr         Disk_FileClose
            * Allocate heap space for the Sprite Group Table
            ldx         ,s
            lda         GDL.NumGroups,x         * Number of groups to load
            clr         <Gfx_NumSpriteGroups    * this starts at zero and grows as we load groups
            ldb         #sizeof{SGT}
            mul
            jsr         MemMgr_Heap_Allocate
            stx         <Gfx_SpriteGroupsPtr
            * Allocate memory for sprite erase data
            jsr         Gfx_SpriteInit
            * Next, load all of the sprite/object groups for this level
            ldx         #Ldr_ObjectFilename
            jsr         Disk_FileOpen
            ldx         ,s
            lda         GDL.NumGroups,x         * Number of groups to load
            ldx         GDL.GroupsPtr,x         * Pointer to list of group numbers to load
            ldy         #Gamedir_Objects
            ldb         ,y+                     * Total number of sprite/object groups in directory
FindGroup@
            pshs        a,b,x,y
            ldb         GDO.GrpNum,y            * next group # in the directory
            cmpb        ,x                      * should we load it?
            beq         LoadThisGroup@
            ldd         GDO.DiskSize,y          * skip over it
            jsr         Disk_FileSeekForward
            puls        a,b,x,y
            leay        sizeof{GDO},y           * advance to next group in directory
            decb
            bne         FindGroup@
            swi                                 * Error: couldnt find all groups in level's group load list
LoadThisGroup@
            jsr         Ldr_Load_SpriteGroup    * Load this group
            puls        a,b,x,y
            leax        1,x                     * next group number to load
            deca
            beq         AllGroupsLoaded@
            leay        sizeof{GDO},y           * advance to next group in directory
            decb
            bne         FindGroup@
            swi                                 * Error: couldn't find all groups in level's group load list
AllGroupsLoaded@
            * close the OBJECTS.DAT file
            jsr         Disk_FileClose
            * initialize the Objects with the OIT
            lda         #VH_BKTILES             * map the (temporary) page for OIT table into $4000
            ldb         #2
            jsr         MemMgr_MapBlock
            ldx         #$4000
            jsr         Obj_Init_CurrentObjectTable
            * Finally, load the tileset
            ldx         #Ldr_TileFilename
            jsr         Disk_FileOpen
            * seek thru this file to start of data block for current tileset
            puls        x                       * X points to level directory entry
            lda         GDL.TilesetNum,x
            ldx         #Gamedir_Tiles
            leax        1,x                     * skip over total # of tilesets
FindTileset2@
            cmpa        GDT.TilesetNum,x
            beq         FoundTileset2@
            pshs        a,x
            ldd         GDT.DiskSize,x          * compressed stream size to skip over
            addd        #32                     * plus 32 for two palettes
            jsr         Disk_FileSeekForward
            puls        a,x
            leax        sizeof{GDT},x
            bra         FindTileset2@
FoundTileset2@
            * load the (uncompressed) palettes
            ldy         #32
            ldu         #Gfx_Palette_CMP_RGB
            pshs        x
            jsr         Disk_FileRead           * load CMP,RGB palettes
            ldx         ,s
            ldd         GDT.DiskSize,x          * D is the number of compressed bytes in this tileset
            jsr         Decomp_Init_Stream      * set up DEFLATE decoder
            * reserve space on the heap for collision mask table, and load the (compressed) table
            clra
            ldb         <Gfx_BkgrndBlockCount   * D is total number of bytes to reserve
            jsr         MemMgr_Heap_Allocate
            stx         <Gfx_CollisionTablePtr
            tfr         d,y                     * Y is number of (uncompressed) bytes to read from zip stream
            tfr         x,u                     * U is pointer to store loaded data
            jsr         Decomp_Read_Stream
            * load the tileset and tilemask blocks
            puls        x
            lda         GDT.NumTiles,x
            clrb
            adda        GDT.NumMasks,x
            rora
            rorb
            tfr         d,y                     * Y is number of tileset bytes to load
            lda         #VH_BKTILES
TilesetLoadLoop@
            pshs        a,y
            ldb         #2                      * map the next page into $4000
            jsr         MemMgr_MapBlock
            cmpy        #$2000
            bls         LastTilesetLoad@
            ldy         #$2000
            ldu         #$4000
            jsr         Decomp_Read_Stream
            puls        a,y
            leay        -$2000,y
            inca
            bra         TilesetLoadLoop@
LastTilesetLoad@
            leas        3,s
            ldu         #$4000
            jsr         Decomp_Read_Stream
 IFDEF DEBUG
            * make sure that we read everything from the compressed stream
            tst         Decomp_OutReadDone
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
            * close the TILES.DAT file
!           jsr         Decomp_Close_Stream
            jsr         Disk_FileClose
            tst         Ldr_SkipSound           * do we need to load the sound data? (this data is only loaded once)
            bne         SkipSound2@
            tst         <Sound_OutputMode       * we also don't load sound data if Output Mode == No Sound
            bmi         SkipSound2@
            tst         Gamedir_Sounds          * if # of sound waveforms is 0, don't bother opening the file
            beq         SkipSound2@
            * First level load, we must load the sound data
            ldx         #Ldr_SoundFilename
            jsr         Disk_FileOpen
            ldx         #Gamedir_Sounds
            lda         ,x+                     * get number of waveforms in SOUNDS.DAT file
LoadSoundLoop@
            pshs        a,x
            ldu         GDS.SizeComp,x          * U is the compressed size
            ldd         GDS.SizeUncomp,x        * D is uncompressed size of this waveform
            beq         NullWaveform@
            pshs        d
            jsr         Ldr_AllocateSoundBuffer
            pshs        a,x                     * save the virtual block # and starting address of waveform block
            tfr         u,d                     * D is compressed size
            jsr         Decomp_Init_Stream      * set up DEFLATE decoder
            ldy         3,s                     * Y is uncompressed size (number of bytes to decode from compressed stream)
            ldu         1,s                     * U is pointer to sound data buffer to store decompressed data
            jsr         Decomp_Read_Stream
 IFDEF DEBUG
            * make sure that we read everything from the compressed stream
            tst         Decomp_OutReadDone
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream     * each waveform is compressed independently, so close this compressed stream
            tst         <Sound_OutputMode
            beq         SoundPrepDAC6@
            * this code prepares the audio waveform for output through the Orchestra-90 card
            ldy         3,s                     * Y is uncompressed size
            ldu         1,s                     * U is pointer to sound data buffer
Orc90Loop@
            lda         ,u
            anda        #$fe                    * clear low bit so we can do 16-bit addition when averaging 2 voices together
            sta         ,u+
            leay        -1,y
            bne         Orc90Loop@
            bra         SoundPrepEnd@
SoundPrepDAC6@
            * this code prepares the audio waveform for output through Coco's built-in DAC
            ldy         3,s                     * Y is uncompressed size
            ldu         1,s                     * U is pointer to sound data buffer
SerialBitSetLoop@
            lda         ,u
            anda        #$fe                    * clear low bit so we can do 16-bit addition when averaging 2 voices together
            ora         #2                      * serial out bit set to 1 so we don't confuse DriveWire
            sta         ,u+
            leay        -1,y
            bne         SerialBitSetLoop@
SoundPrepEnd@
            lda         ,s                      * A is virtual block # of this waveform buffer
            suba        #VH_SOUNDDATA
            clrb
            lsla
            lsla
            lsla
            lsla
            lsla
            suba        #$40
            addd        1,s
            tfr         d,u                     * U is sound buffer page index (upper 3 bits) and offset (lower 13 bits)
            leas        5,s
NullWaveform@
            puls        a,x
            stu         2,x                     * replace compressed size in directory with starting page index/offset
            leax        4,x
            deca
            bne         LoadSoundLoop@
            * close the SOUNDS.DAT file
            jsr         Disk_FileClose
SkipSound2@
            * disable progress callback
            ldx         #0
            jsr         Disk_SetProgressCallback
            * set the SkipSound flag, so we won't re-load the sound data later
            lda         #1
            sta         Ldr_SkipSound
            * call the level's initialization function
            jsr         [Ldr_LDD.PtrInitLevel]
            * set up graphics variables
            jsr         Gfx_InitBkgrndBounds
            * draw the offscreen buffer pair
            jsr         Gfx_InitialScreenFill
            * fade out and clear border
            clr         Gfx_PalIdx_BKColor
            lda         #1
            jsr         Img_FadeOut
            clr         $FF9A
            * set the new palette
            jsr         System_SetPaletteAuto
            * fade in to the starting level screen
            lda         #$FF
            sta         Gfx_PalIdx_FGColor
            clr         Gfx_PalIdx_BKColor
            lda         #0
            jsr         Img_FadeIn
            * redraw the onscreen buffer pair (it's necessary to get the odd screen buffer in pair 0)
            clr         <Gfx_RenderingFrameX4   * set back buffer to first pair
            orcc        #$50
            inc         <Gfx_LastRenderedFrame
            jsr         Gfx_InitialScreenFill
            andcc       #$AF
            * at the end, we jump into the main loop
            jmp         mainloop


* - IN:      D=size of sound data block to allocate
* - OUT:     A=virtual handle for code page, X=pointer to allocated & mapped block (base $4000)
* - Trashed: A,B,X,Y
*
BlockSize@              rmb     2
*
Ldr_AllocateSoundBuffer
            std         BlockSize@
            * try to find an existing code page which can accomodate this block
            ldy         #Sound_WavePageEndPtrs
            lda         <Sound_NumWavePages
            beq         CreateNewPage@
PageSearchLoop@
            pshs        a
            ldd         ,y
            addd        BlockSize@
            cmpd        #$6000                  * does this page have enough free space?
            bhi         NotEnoughSpace@
            std         ,y                      * yes, so store new end pointer
            subd        BlockSize@              * get the block's starting pointer
            tfr         d,x                     * return it in X
            tfr         y,d
            subd        #Sound_WavePageEndPtrs
            lsrb                                * B is index to this code page in the loader sprite page lists
            addb        #VH_SOUNDDATA
            tfr         b,a                     * A is virtual handle for the selected code page
            leas        1,s
            rts
NotEnoughSpace@
            puls        a
            leay        2,y
            deca
            bne         PageSearchLoop@
CreateNewPage@                                  * Y is pointer to page end pointer (in list) for new page
            lda         <Sound_NumWavePages
            inca
 IFDEF DEBUG
            cmpa        #8
            bls         >
            swi                                 * Error: out of memory for Sprite draw/erase code blocks
 ENDC
!           sta         <Sound_NumWavePages     * update # of sound data pages in list
            ldd         #$4000
            addd        BlockSize@
            std         ,y                      * store ending pointer for new code page
            tfr         y,d
            subd        #Sound_WavePageEndPtrs
            lsrb                                * B is index for this code page in the loader sprite page lists
            addb        #VH_SOUNDDATA
            tfr         b,a
            jsr         MemMgr_AllocateBlock    * allocate page at high address
            pshs        a
            ldb         #2                      * map the page into $4000
            jsr         MemMgr_MapBlock
            puls        a
            ldx         #$4000                  * this block is at the beginning of the page
            rts


* - IN:      Y is pointer to sprite group in Object directory
* - OUT:     N/A
* - Trashed: All
*
GroupObjCodeSize@       zmb     2
GroupCompSpriteCode@    zmb     2
GroupCompObjectCode@    zmb     2
ObjCodePtr@             zmb     2
*
Ldr_Load_SpriteGroup
            * Start by setting up this group's entry in the Sprite Group Table
            lda         <Gfx_NumSpriteGroups    * calculate starting pointer to this group's SGT entry
            inc         <Gfx_NumSpriteGroups
            ldb         #sizeof{SGT}
            mul
            ldx         <Gfx_SpriteGroupsPtr
            ADD_D_TO_X
            ldd         GDO.ObjCodeSize,y       * store this group's object code size in a local variable
            std         GroupObjCodeSize@
            ldd         GDO.CompSpriteCodeSize,y
            std         GroupCompSpriteCode@
            ldd         GDO.CompObjCodeSize,y
            std         GroupCompObjectCode@
            lda         GDO.GrpNum,y            * copy group number to SGT
            sta         SGT.groupIdx,x
            lda         GDO.NumSprites,y        * copy sprite count to SGT
            sta         SGT.spCount,x
            ldb         #sizeof{SDT}            * allocate memory for Sprite Descriptor Table
            mul
            pshs        x,y
            jsr         MemMgr_Heap_Allocate
            tfr         x,d
            puls        x,y
            std         SGT.sprites,x
            lda         GDO.NumObjects,y        * copy object counts to SGT
            sta         SGT.obCount,x
            ldb         #sizeof{ODT}            * allocate memory for Object Descriptor Table
            mul
            pshs        x,y
            jsr         MemMgr_Heap_Allocate
            tfr         x,d
            puls        x,y
            std         SGT.objects,x
            clr         SGT.rowcrop,x           * clear the rowcrop pointer
            clr         SGT.rowcrop+1,x
            * Next, load the Sprite Descriptor Table
            pshs        x
            lda         SGT.spCount,x
            ldb         #sizeof{SDT}
            mul
            tfr         d,y
            ldu         SGT.sprites,x
            jsr         Disk_FileRead
            * Next, load the Object Descriptor Table
            ldx         ,s
            lda         SGT.obCount,x
            ldb         #sizeof{ODT}
            mul
            tfr         d,y
            ldu         SGT.objects,x
            jsr         Disk_FileRead
            * set up DEFLATE decoder
            ldd         GroupCompSpriteCode@
            jsr         Decomp_Init_Stream      
            * Load sprites and fix up the Sprite Descriptor Table
            ldx         ,s                      * X is pointer to this group's SGT entry
            lda         SGT.spCount,x           * A = number of sprites
            ldx         SGT.sprites,x           * X = pointer to loaded Sprite Descriptor Table for this group
SpriteLoop@
            pshs        a,x
            ldd         SDT.drawLeft,x          * number of bytes in DrawLeft
            jsr         Ldr_AllocateSpriteCode
            ldu         1,s
            sta         SDT.cpLeft,u
            ldy         SDT.drawLeft,u          * number of bytes to load
            stx         SDT.drawLeft,u
            pshs        x
            ldb         #2                      * map the page at $4000
            jsr         MemMgr_MapBlock
            puls        u
            jsr         Decomp_Read_Stream      * load Sprite DrawLeft machine code from disk file
            ldu         1,s
            ldd         SDT.drawRight,u         * number of bytes in DrawRight
            beq         >
            jsr         Ldr_AllocateSpriteCode
            ldu         1,s
            sta         SDT.cpRight,u
            ldy         SDT.drawRight,u         * number of bytes to load
            stx         SDT.drawRight,u
            pshs        x
            ldb         #2                      * map the page at $4000
            jsr         MemMgr_MapBlock
            puls        u
            jsr         Decomp_Read_Stream      * load Sprite DrawRight machine code from disk file
            ldu         1,s
!           ldd         SDT.erase,u             * number of bytes in Erase
            jsr         Ldr_AllocateSpriteCode
            ldu         1,s
            sta         SDT.cpErase,u
            ldy         SDT.erase,u             * number of bytes to load
            stx         SDT.erase,u
            pshs        x
            ldb         #2                      * map the page at $4000
            jsr         MemMgr_MapBlock
            puls        u
            jsr         Decomp_Read_Stream      * load Sprite Erase machine code from disk file
            puls        a,x
            leax        sizeof{SDT},x
            deca
            bne         SpriteLoop@
            * close Sprite compressed stream, and re-initialize DEFLATE decoder for compressed object code stream
 IFDEF DEBUG
            tst         Decomp_OutReadDone      * make sure that we read everything from the compressed stream
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream
            ldd         GroupCompObjectCode@
            jsr         Decomp_Init_Stream      
            * Allocate memory for object code and load it from disk file
            ldd         Ldr_LvlObjCodeEndPtr    * end pointer in $6000 block of level/object code
            tfr         d,u
            std         ObjCodePtr@
            addd        GroupObjCodeSize@
 IFDEF DEBUG
            cmpd        #$8000
            bls         >
            swi                                 * Error: out of memory for level / object code
 ENDC
!           std         Ldr_LvlObjCodeEndPtr    * update end pointer
            ldy         GroupObjCodeSize@
            jsr         Decomp_Read_Stream      * read the object handling code
            * close compressed object code stream
 IFDEF DEBUG
            tst         Decomp_OutReadDone      * make sure that we read everything from the compressed stream
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream
            * Fix up the Object Descriptor Table
            puls        x
            lda         SGT.obCount,x           * A = number of objects
            ldx         SGT.objects,x           * X = pointer to loaded Object Descriptor Table for this group
ObjectLoop@            
            pshs        a
            ldd         ODT.init,x              * fix up the function pointers
            addd        ObjCodePtr@
            std         ODT.init,x
            ldd         ODT.reactivate,x
            addd        ObjCodePtr@
            std         ODT.reactivate,x
            ldd         ODT.update,x
            addd        ObjCodePtr@
            std         ODT.update,x
            ldd         ODT.draw,x
            addd        ObjCodePtr@
            std         ODT.draw,x
            puls        a
            leax        sizeof{ODT},x
            deca
            bne         ObjectLoop@
            rts


* - IN:      D=size of code block to allocate
* - OUT:     A=virtual handle for code page, X=pointer to allocated block (mapped to $4000)
* - Trashed: A,B,X,Y
*
BlockSize@              rmb     2
*
Ldr_AllocateSpriteCode
            std         BlockSize@
            * try to find an existing code page which can accomodate this block
            ldy         #Ldr_SpritePageEndPtrs
            lda         Ldr_NumSpriteCodePages
            beq         CreateNewPage@
PageSearchLoop@
            pshs        a
            ldd         ,y
            addd        BlockSize@
            cmpd        #$6000                  * does this page have enough free space?
            bhi         NotEnoughSpace@
            std         ,y                      * yes, so store new end pointer
            subd        BlockSize@              * get the block's starting pointer
            tfr         d,x                     * return it in X
            tfr         y,d
            subd        #Ldr_SpritePageEndPtrs
            lsrb                                * B is index to this code page in the loader sprite page lists
            addb        #VH_SPRCODE
            tfr         b,a                     * A is virtual handle for the selected code page
            leas        1,s
            rts
NotEnoughSpace@
            puls        a
            leay        2,y
            deca
            bne         PageSearchLoop@
CreateNewPage@                                  * Y is pointer to page end pointer (in list) for new page
            lda         Ldr_NumSpriteCodePages
            inca
 IFDEF DEBUG
            cmpa        #MAX_SPRITE_CODE_PAGES
            bls         >
            swi                                 * Error: out of memory for Sprite draw/erase code blocks
 ENDC
!           sta         Ldr_NumSpriteCodePages  * update # of code pages in list
            ldd         #$4000
            addd        BlockSize@
            std         ,y                      * store ending pointer for new code page
            tfr         y,d
            subd        #Ldr_SpritePageEndPtrs
            lsrb                                * B is index for this code page in the loader sprite page lists
            addb        #VH_SPRCODE
            tfr         b,a
            jsr         MemMgr_AllocateBlock    * allocate page at high address
            ldx         #$4000                  * this block is at the beginning of the page
            rts

* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X,Y
*
Ldr_ProgressCallback
            ldd         Ldr_CurProgressSec
            INCREMENT_D
            cmpd        Ldr_SectorsToLoad
            bls         >
            rts                                 * already at 100%
!           std         Ldr_CurProgressSec      * calculate progress in units of 1/64th (psuedo-percent)
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola                                * D is number of sectors loaded * 64
            std         Math_Dividend_16
            ldd         Ldr_SectorsToLoad
            std         Math_Divisor_16
            jsr         Math_Divide16by16
            lda         Math_Quotient_16+1      * between 0 and 64
            cmpa        Ldr_CurProgressPct      * make sure we're going up
            bhi         >
            rts
!           ldd         $FFA2                   * save the old pages mapped to $4000-$7FFF
            anda        #$3f
            andb        #$3f
            pshs        a,b
            lda         Ldr_ProgressBarPage     * Map graphics pages for progress bar
            sta         $FFA2
            inca
            sta         $FFA3
            ldx         Ldr_ProgressBarPtr
            leax        257,x                   * X is pointer to top-left byte in progress bar
            lda         Math_Quotient_16+1      * between 0 and 64
            sta         Ldr_CurProgressPct      * A is number of columns to draw
ColumnLoop@
            * Now we will draw columns 2 at a time
            cmpa        #2
            blo         ColumnLoopDone@
            pshs        a,x
            ldb         #10
            lda         Gfx_PalIdx_BarColor
DrawColumn2@
            sta         ,x
            leax        256,x
            decb
            bne         DrawColumn2@
            puls        a,x
            leax        1,x
            suba        #2
            bra         ColumnLoop@
ColumnLoopDone@
            ldb         Ldr_CurProgressPct      * we don't draw the last column if the bar is full
            cmpb        #64
            beq         ProgressDone@
            ldb         #10
            tsta                                * do we draw foreground column in left or right nibble?
            beq         FG0@
            lda         Gfx_PalIdx_BarColor
            anda        #$f0
            sta         SMC_Or1@+1
            lda         Gfx_PalIdx_FGColor
            anda        #$0f
SMC_Or1@
            ora         #0
            bra         DrawColumn3@
FG0@
            lda         Gfx_PalIdx_FGColor
            anda        #$f0
            sta         SMC_Or2@+1
            lda         Gfx_PalIdx_BKColor
            anda        #$0f
SMC_Or2@
            ora         #0
DrawColumn3@
            sta         ,x
            leax        256,x
            decb
            bne         DrawColumn3@
ProgressDone@
            * remap the original pages and return
            puls        a,b
            std         $FFA2
            rts

***********************************************************
* Ldr_Unload_Level:
*   This function unloads all data from current level
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: All 
***********************************************************
*
*
Ldr_Unload_Level
            * 1. Start by freeing all of the 8k blocks allocated
            lda         #VH_LVLOBJCODE          * free the level/object code page
            jsr         MemMgr_FreeBlock
            ldb         Ldr_NumSpriteCodePages  * free the Sprite Draw/Erase code pages
            lda         #VH_SPRCODE
FreeSpritePages@
            pshs        a,b,x
            jsr         MemMgr_FreeBlock
            puls        a,b,x
            inca
            decb
            bne         FreeSpritePages@
            clr         Ldr_NumSpriteCodePages
            jsr         Gfx_SpriteUninit        * free the Sprite erase data page
            ldb         <Gfx_BkgrndBlockPages   * free the Tileset pages
            lda         #VH_BKTILES
FreeTilesetPages@
            pshs        a,b,x
            jsr         MemMgr_FreeBlock
            puls        a,b,x
            inca
            decb
            bne         FreeTilesetPages@
            clr         <Gfx_BkgrndBlockPages
            ldb         <Gfx_BkgrndMapPages     * free the Tilemap pages
            lda         #VH_BKMAP
FreeTilemapPages@
            pshs        a,b,x
            jsr         MemMgr_FreeBlock
            puls        a,b,x
            inca
            decb
            bne         FreeTilemapPages@
            clr         <Gfx_BkgrndMapPages
            * 2. Then, free all of the heap blocks allocated
            * Free the collision table
            ldx         <Gfx_CollisionTablePtr
            jsr         MemMgr_Heap_FreeLast
            *    Free the Objects' state data
            jsr         Obj_Uninit_Objects
            *    For each sprite/object group, free the Object and Sprite Descriptor Tables
            lda         <Gfx_NumSpriteGroups
            ldb         #sizeof{SGT}
            mul
            ldu         <Gfx_SpriteGroupsPtr
            ADD_D_TO_U
FreeGroups@
            cmpu        <Gfx_SpriteGroupsPtr
            beq         >
            leau        -sizeof{SGT},u
            ldx         SGT.objects,u
            jsr         MemMgr_Heap_FreeLast
            ldx         SGT.sprites,u
            jsr         MemMgr_Heap_FreeLast
            bra         FreeGroups@
            *    free the Sprite Group Table
!           tfr         u,x
            jsr         MemMgr_Heap_FreeLast
            *    free the Current Object Table
            ldx         <Obj_CurrentTablePtr
            jsr         MemMgr_Heap_FreeLast
            * 3. Finally, free up the graphics aperature
            jsr         MemMgr_FreeGfxAperature
            rts


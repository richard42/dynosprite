*********************************************************************************
* DynoSprite - graphics-image.asm
* Copyright (c) 2014, Richard Goedeken
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
Img_ImageFilename       fcc     'IMAGES  DAT'

***********************************************************
* Img_Load_Splash_Image:
*   This function loads a given splash image at a given point on
*   the back screen buffer
*
* - IN:      U = Image # to load
*            A = Y coordinate (in rows) of upper edge of loaded image
*            B = X coordinate (in bytes) of left edge of loaded image
* - OUT:     N/A
* - Trashed: All
***********************************************************
*
Img_Load_Splash_Image
            pshs        u
            * begin by calculating the starting memory page and address at which to load the splash image
            jsr         Gfx_GetPixelAddress_Back * (A=page number, Y=offset)
            sta         <GfxMemPage@,PCR
            puls        d                       * get image # in B (demoting to 8 bits by taking LSB)
            pshs        y                       * save the page offset on the stack
            stb         <ImageNumber@,PCR
 IFDEF DEBUG
            cmpb        Gamedir_Images
            blo         >
            swi                                 * Image number is invalid
 ENDC
            * Set up environment for disk access
!           ldx         #0
            jsr         Disk_SetProgressCallback
            jsr         System_EnterDiskMode
            * open the IMAGES.DAT file
            ldx         #Img_ImageFilename
            jsr         Disk_FileOpen
            * seek thru this file to start of data block for current image
            ldx         #Gamedir_Images+1
SeekToImage@
            tst         <ImageNumber@,PCR       * number of images remaining to seek past
            beq         FoundImage@
            dec         <ImageNumber@,PCR
            ldd         GDI.SizeComp,x
            beq         EmptyImage@
            addd        #35                     * also need to seek over the palettes
            pshs        x
            jsr         Disk_FileSeekForward
            puls        x
EmptyImage@
            leax        sizeof{GDI},x
            bra         SeekToImage@
FoundImage@
            * set up local variables based on size of image to load
            lda         GDI.HeightRows,x
            sta         <RowsToLoad@,PCR
            clra
            ldb         GDI.WidthBytes,x
            std         <BytesToLoad@,PCR
            * load the palettes
            ldy         #35                     * There are two 16-byte palettes, plus 3 special color indices
            ldu         #Gfx_Palette_CMP_RGB
            pshs        x
            jsr         Disk_FileRead
            * duplicate the nybbles in the special color values
            lda         Gfx_PalIdx_BarColor
            lsla
            lsla
            lsla
            lsla
            ora         Gfx_PalIdx_BarColor
            sta         Gfx_PalIdx_BarColor
            lda         Gfx_PalIdx_FGColor
            lsla
            lsla
            lsla
            lsla
            ora         Gfx_PalIdx_FGColor
            sta         Gfx_PalIdx_FGColor
            lda         Gfx_PalIdx_BKColor
            lsla
            lsla
            lsla
            lsla
            ora         Gfx_PalIdx_BKColor
            sta         Gfx_PalIdx_BKColor
            bra         ClearScreen@
*
ImageNumber@    fcb     0
GfxMemPage@     fcb     0
RowsToLoad@     fcb     0
BytesToLoad@    fdb     0
*
ClearScreen@
            * set all pixels in the back buffer to the background palette value
            jsr         Gfx_FillScreen_Back
            * map screen buffer to $6000-$9FFF
            lda         <GfxMemPage@,PCR
            tfr         a,b
            incb
            std         $FFA3
            stb         <GfxMemPage@,PCR
            * initialize decompressor
            puls        x
            ldd         GDI.SizeComp,x          * D is the number of compressed bytes for the image
            jsr         Decomp_Init_Stream      * set up DEFLATE decoder
            * prepare to load image lines
            puls        u                       * U is starting page offset
            leau        $6000,u                 * now U is address to load the first line
LoadLine@
            pshs        u
            ldy         <BytesToLoad@,PCR
            jsr         Decomp_Read_Stream      * read one line
            puls        u
            leau        256,u                   * advance to next line
            cmpu        #$8000
            blo         >
            leau        -$2000,u
            lda         <GfxMemPage@,PCR
            sta         $FFA3
            inca
            sta         $FFA4
            sta         <GfxMemPage@,PCR
!           dec         <RowsToLoad@,PCR
            bne         LoadLine@
 IFDEF DEBUG
            tst         Decomp_OutReadDone      * make sure that we read everything from the uncompressed stream
            bne         >
            swi                                 * Error: we didn't read all of the data in the stream
 ENDC
!           jsr         Decomp_Close_Stream
            * close the IMAGES.DAT file
            jsr         Disk_FileClose
            rts


***********************************************************
* Img_FadeOut:
*   This function fills up the current front buffer with the background color byte in
*   a gradual way.  Multiple fading algorithms are supported.
*
* - IN:      A = Fade out algorithm
*                0: vertical shades
*                1: random pixels
* - OUT:     N/A
* - Trashed: All
***********************************************************
*
Img_FadeOut
 IFDEF DEBUG
            cmpa        #2
            blo         >
            swi                                 * Fade out algorithm number is invalid
 ENDC
!           ldx         #Img_FadeOutTable
            lsla
            ldu         a,x                     * U is address of fade-out routine to jump to
            ldd         $FFA3                   * save previous value of page map to restore after the fade
            std         RestorePageMap@+1
            ldd         #0                      * get memory address of top-left pixel in screen
            jsr         Gfx_GetPixelAddress_Front   * (A=page number, Y=offset)
            tfr         a,b
            incb
            std         $FFA3                   * map screen buffer to $6000-$9FFF
            jsr         ,u
RestorePageMap@
            ldd         #0                      * SMC: page mapping value is written by code above
            std         $FFA3
            rts

Img_FadeOutTable        fdb     Img_FadeOut0
                        fdb     Img_FadeOut1

Img_FadeOut0
            leay        $6000,y
            pshs        y,a                     * store starting address
            * start by calculating the address of pixel (0,200) to know when we've gone past end of image
            adda        #6                      * 6 8k pages * 32 lines/page = 192 lines
            leax        2048,y                  * 256 bytes/line * 8 lines = 2048 bytes
            cmpx        #$8000
            blo         >
            inca
            leax        -$2000,x
!           pshs        x,a
            clra                                * row counter
            pshs        b,a
FrameStart@
            sync
RowLoop@
            lda         Gfx_PalIdx_BKColor      * A is the color that we're fading out to
            tfr         a,b
            tfr         d,u
            ldb         #160/2                  * column counter
ColLoop1@
            stu         ,y++
            decb
            bne         ColLoop1@
            leay        96,y                    * move forward past remainder of current row
            lda         ,s
            cmpa        #19
            beq         SkipFGLine@
            lda         Gfx_PalIdx_FGColor
            tfr         a,b
            tfr         d,u
            ldb         #160/2
ColLoop2@
            stu         ,y++
            decb
            bne         ColLoop2@
            leay        -160,y
SkipFGLine@
            ldb         1,s                     * B is address of second 8k page in our image window
            leay        19*256,y                * move forward 19 rows
            cmpy        #$8000
            blo         >
            leay        -$2000,y
            stb         $FFA3
            incb
            stb         $FFA4
            stb         1,s
!           decb                                * B is address of first 8k page in our image window
            cmpb        2,s
            blo         RowLoop@
            bhi         >
            cmpy        3,s
            blo         RowLoop@
!           inc         ,s                      * go back to the top of the image, and advance the row counter by 1
            lda         ,s
            cmpa        #20
            blo         >
            leas        8,s
            rts                                 * all done
!           clrb                                * now D is # of bytes to advance to get to starting row
            ldy         6,s
            leay        d,y
            lda         5,s
            tfr         a,b
            incb
            std         $FFA3
            stb         1,s
            bra         FrameStart@

Img_FadeOut1
            * store starting page and offset
            sty         AddOffsetWord@+1
            sta         AddPageByte@+1
            ldx         #Img_Random161
            ldu         #Img_Random200
PixelLoop@
            lda         ,u+                     * get this pixel's Y coordinate
            ldb         ,x+                     * get this pixel's X coordinate
AddOffsetWord@
            addd        #0                      * SMC: offset value stored in code above
            sta         ReloadOffsetHi@+1
            lsra
            lsra
            lsra
            lsra
            lsra
AddPageByte@
            adda        #0                      * SMC: offset value stored in code above
            sta         $FFA3
ReloadOffsetHi@
            lda         #0                      * SMC: hi byte of offset to load here was stored above
            anda        #$1F
            ora         #$60
            tfr         d,y
            lda         Gfx_PalIdx_BKColor
            sta         ,y
            cmpx        #Img_Random161+161
            bne         >
            ldx         #Img_Random161
!           cmpu        #Img_Random200+200
            bne         PixelLoop@
            ldu         #Img_Random200
            cmpx        #Img_Random161
            bne         PixelLoop@
            rts

***********************************************************
* Img_FadeIn:
*   This function copies pixels from the back to the front buffer in
*   a gradual way.  Multiple fading algorithms are supported.
*
* - IN:      A = Fade in algorithm
*                0: vertical shades
*                1: random pixels
*            Note: front buffer must be in slot 0, and back/front buffers must start at same global X,Y
* - OUT:     N/A
* - Trashed: All
***********************************************************
*
Img_FadeIn
 IFDEF DEBUG
            cmpa        #2
            blo         >
            swi                                 * Fade out algorithm number is invalid
 ENDC
!           ldx         #Img_FadeInTable
            lsla
            ldu         a,x                     * U is address of fade-in routine to jump to
            ldd         #0                      * get memory address of top-left pixel in screen
            jsr         Gfx_GetPixelAddress_Front   * (A=page number, Y=offset)
            tfr         a,b
            incb
            std         $FFA3                   * map screen buffer to $6000-$9FFF
            addd        #$0E0E                  * 2nd buffer pair is 14 pages ahead 
            std         $FFA5
            subd        #$0E0E
            jsr         ,u
            lda         Gfx_PalIdx_BKColor      * set screen border to background color
            sta         $FF9A
            rts

Img_FadeInTable         fdb     Img_FadeIn0
                        fdb     Img_FadeIn1

Img_FadeIn0
            leay        $6000,y
            pshs        y,a                     * store starting address
            * start by calculating the address of pixel (0,200) to know when we've gone past end of image
            adda        #6                      * 6 8k pages * 32 lines/page = 192 lines
            leax        2048,y                  * 256 bytes/line * 8 lines = 2048 bytes
            cmpx        #$8000
            blo         >
            inca
            leax        -$2000,x
!           pshs        x,a
            clra                                * row counter
            pshs        b,a
TopBlind@
            sync
RowLoop@
            ldb         #160/4                  * column counter
ColLoop1@
            ldu         $4000,y
            stu         ,y++
            ldu         $4000,y
            stu         ,y++
            decb
            bne         ColLoop1@
            leay        96,y                    * move forward past remainder of current row
            lda         ,s
            cmpa        #19
            beq         SkipFGLine@
            lda         Gfx_PalIdx_FGColor
            tfr         a,b
            tfr         d,u
            ldb         #160/4
ColLoop2@
            stu         ,y++
            stu         ,y++
            decb
            bne         ColLoop2@
            leay        -160,y
SkipFGLine@
            ldb         1,s                     * B is address of next 8k page for start of window
            leay        19*256,y                * move forward 19 rows
            cmpy        #$8000
            blo         >
            leay        -$2000,y
            tfr         b,a
            incb
            std         $FFA3
            stb         1,s
            addd        #$0E0E
            std         $FFA5
            subb        #14
!           decb                                * B is address of first 8k page in our image window
            cmpb        2,s
            blo         RowLoop@
            bhi         >
            cmpy        3,s
            blo         RowLoop@
!           inc         ,s                      * go back to the top of the image, and advance the row counter by 1
            lda         ,s
            cmpa        #20
            blo         >
            leas        8,s
            rts                                 * all done
!           clrb                                * now D is # of bytes to advance to get to starting row
            ldy         6,s
            leay        d,y
            lda         5,s
            tfr         a,b
            incb
            std         $FFA3
            stb         1,s
            addd        #$0E0E
            std         $FFA5
            bra         TopBlind@

Img_FadeIn1
            * store starting page and offset
            sty         AddOffsetWord@+1
            sta         AddPageByte@+1
            ldx         #Img_Random161
            ldu         #Img_Random200
PixelLoop@
            lda         ,u+                     * get this pixel's Y coordinate
            ldb         ,x+                     * get this pixel's X coordinate
AddOffsetWord@
            addd        #0                      * SMC: offset value stored in code above
            sta         ReloadOffsetHi@+1
            lsra
            lsra
            lsra
            lsra
            lsra
AddPageByte@
            adda        #0                      * SMC: offset value stored in code above
            sta         $FFA3
            adda        #14
            sta         $FFA4
ReloadOffsetHi@
            lda         #0                      * SMC: hi byte of offset to load here was stored above
            anda        #$1F
            ora         #$60
            tfr         d,y
            lda         $2000,y
            sta         ,y
            cmpx        #Img_Random161+161
            bne         >
            ldx         #Img_Random161
!           cmpu        #Img_Random200+200
            bne         PixelLoop@
            ldu         #Img_Random200
            cmpx        #Img_Random161
            bne         PixelLoop@
            rts



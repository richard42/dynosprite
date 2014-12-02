*********************************************************************************
* DynoSprite - decompress.asm
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

* -----------------------------------------------------------------------------
* -- Local data members
* -----------------------------------------------------------------------------
* From Decompressors point of view, the Input stream is the compressed bitstream
* read from the disk file, which the Output stream is the uncompressed data
* which is written to client buffers

Decomp_InFileBytesLeft  zmb     2               * number of compressed bytes remaining to be read from disk file
Decomp_InCurPtr         zmb     2               * pointer to current byte being read in input buffer by decompressor
Decomp_InBufferEnd      zmb     2               * pointer to byte following last valid byte in input buffer
Decomp_InBitMask        zmb     1               * bit mask for next bit to read from input buffer
Decomp_OutBufferHandles zmb     5               * first page is one being written to, second page is older, etc
Decomp_OutWriteDone     zmb     1               * flag set to 1 when all compressed bytes have been decoded to output buffer
* Decomp_OutWritePage                           * Output buffer write page is always the first one in the OutBufferHandles list
Decomp_OutWritePtr      zmb     2               * $8000-based pointer to next byte to be written from decompressor
Decomp_OutReadDone      zmb     1               * flag set to 1 when all uncompressed bytes in stream have been read by client
Decomp_OutReadPage      zmb     1               * index to OutBufferHandles list for page being read by client
Decomp_OutReadPtr       zmb     2               * $8000-based pointer to next byte to be read by client
Decomp_RestorePages     zmb     2               * save/restore page $FFA2/3 physical blocks
Decomp_BFINAL           zmb     1
Decomp_BTYPE            zmb     1
Decomp_CodeLengthOrder  fcb     16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15

* This macro gives table locations in the Decompression Data page
DecompData  STRUCT
InBuffer                rmb     256
CodeLengths             rmb     258+31+31
CodeCountByLength       rmb     16
LenHuffmanTree          rmb     19*4
LiteralHuffmanTree      rmb     288*4
DistHuffmanTree         rmb     32*4
            ENDSTRUCT

* -----------------------------------------------------------------------------
* -- Global Functions (for clients)
* -----------------------------------------------------------------------------


***********************************************************
* Decomp_Init_Stream:
*   This function sets up internal data members and allocates memory to use during
*   the decompression of a DEFLATE stream from a file on disk.  Before this function
*   is called, the file must already be open and positioned at the starting point of
*   the compressed data stream.
*
* - IN:      D = number of bytes in compressed stream on disk
* - OUT:     N/A
* - Trashed: All
***********************************************************
*
Decomp_Init_Stream
            std         Decomp_InFileBytesLeft  * store number of compressed bytes in this stream
            clr         Decomp_OutReadDone      * clear flags which signify when all uncompressed bytes have been written/read
            clr         Decomp_OutWriteDone
            ldd         #$8000
            stb         Decomp_OutReadPage      * set initial output read page to 0 (newest)
            std         Decomp_OutWritePtr      * set initial output read/write pointers to start of buffer
            std         Decomp_OutReadPtr
            * save the physical page numbers mapped to $4000-$7FFF for later restoration
            ldd         $FFA2
            anda        #$3F
            andb        #$3F
            std         Decomp_RestorePages
            * Allocate 8k block for decompressor data structures
            lda         #VH_ZIPDATA
            jsr         MemMgr_AllocateBlock
            stb         $FFA2                   * map it to $4000-$5FFF
            * Allocate five 8k blocks to store uncompressed data (one for current write buffer and 4 for history)
            lda         #VH_ZIPBUF
            ldu         #Decomp_OutBufferHandles
!           sta         ,u+
            jsr         MemMgr_AllocateBlock
            inca
            cmpa        #VH_ZIPBUF+5
            bne         <
            * load up the input buffer
            jsr         Decomp_ReloadInputBuffer
            * initialize the first DEFLATE block
            jsr         Decomp_Init_Deflate_Block
            * decompress everything we can to fill up at least one 8k page of uncompressed output data
            jsr         Decomp_ReloadOutputBuffer
            * restore two 8k pages that were previously mapped to $4000-$7FFF
            ldd         Decomp_RestorePages
            std         $FFA2
            rts


***********************************************************
* Decomp_Close_Stream:
*   Frees memory blocks used during decompression.
*
* - IN:      N/A
* - OUT:     N/A
***********************************************************
*
Decomp_Close_Stream
            * free all of our memory pages
            lda         #VH_ZIPDATA
            jsr         MemMgr_FreeBlock
            lda         #VH_ZIPBUF
!           pshs        a
            jsr         MemMgr_FreeBlock
            puls        a
            inca
            cmpa        #VH_ZIPBUF+5
            bne         <
            rts

***********************************************************
* Decomp_Read_Stream:
*   Copies uncompressed data from our decode buffer to the client buffer
*   Note that this function has the same interface as Disk_FileRead
*
* - IN:      Y = number of bytes to read, U = pointer to buffer to load data
* - OUT:     N/A
* - Trashed: A,B,X,Y,U
***********************************************************
*
CopyUpdatePtr@          zmb     2               * point at which we must switch to new page and/or reload data
*
Decomp_Read_Stream
 IFDEF DEBUG
            tst         Decomp_OutReadDone
            beq         >
            swi                                 * Error: read past end of uncompressed stream
 ENDC
            * Map in the current page being read from output buffer
!           lda         Decomp_OutReadPage
            ldx         #Decomp_OutBufferHandles
            ldb         a,x
            ldx         #MemMgr_VirtualTable
            ldb         b,x
            stb         $FFA4                   * map it to $8000
            * Calculate point at which we must stop copying to either switch pages or decode more data
            ldx         #$A000                  * assume we can copy until end of page
            tsta                                * if read page index is > 0, then we have a full page
            bne         >                       * of decompressed data to read
            ldx         Decomp_OutWritePtr      * otherwise we must end reading at the current write end pointer
!           stx         CopyUpdatePtr@
            * start the copying
            ldx         Decomp_OutReadPtr
DoCopy@
            lda         ,x+
            sta         ,u+
            cmpx        CopyUpdatePtr@
            beq         UpdateState@
CopyLoopTail@
            leay        -1,y                    * loop back for all remaining bytes to copy
            bne         DoCopy@
            stx         Decomp_OutReadPtr
            rts
UpdateState@
            cmpx        #$A000                  * do we need to move read pointer forward by a page?
            bne         ReloadOutputPage@
            dec         Decomp_OutReadPage      * yes move page index forward by 1
 IFDEF DEBUG
            bpl         >
            swi                                 * error, write page idx should always be equal to or 1 ahead of
                                                * the read page idx, so read page idx should never go negative here
!           beq         >
            swi                                 * error, read page idx should never be greater than 1
 ENDC
!           lda         Decomp_OutReadPage      * map in the new read page (which must be index 0 in our list)
            ldx         #Decomp_OutBufferHandles
            ldb         a,x
            ldx         #MemMgr_VirtualTable
            ldb         b,x
            stb         $FFA4                   * map it to $8000
            ldx         Decomp_OutWritePtr      * the new page read must end reading at the current write end pointer
            stx         CopyUpdatePtr@
            ldx         #$8000                  * place read pointer at start of new page
            cmpx        Decomp_OutWritePtr      * if the new page contains no loaded data
            bne         CopyLoopTail@           * then it needs to be reloaded, otherwise continue copy
ReloadOutputPage@
            stx         Decomp_OutReadPtr
            cmpy        #1                      * did we just copy the last byte?
            bne         >
            tst         Decomp_OutWriteDone     * yes. is the compressed stream finished?
            beq         >
            inc         Decomp_OutReadDone      * yes, so this should also be the end of the uncompressed stream
            rts
!           pshs        x,y,u
            * save the physical page numbers mapped to $4000-$7FFF for later restoration
            ldd         $FFA2
            anda        #$3F
            andb        #$3F
            std         Decomp_RestorePages
            * Map in 8k block for decompressor data structures
            lda         <MemMgr_VirtualTable+VH_ZIPDATA
            sta         $FFA2                   * map it to $4000-$5FFF
            * Load data from uncompressed stream to fill up current newest page
            jsr         Decomp_ReloadOutputBuffer
            * restore two 8k pages that were previously mapped to $4000-$7FFF
            ldd         Decomp_RestorePages
            std         $FFA2
            puls        x,y,u
            tst         Decomp_OutWriteDone     * is the compressed stream finished?
            beq         KeepGoing@
            tst         Decomp_OutReadPage      * yes, it's finished.  Are we reading the last page?
            bne         KeepGoing@
            cmpx        Decomp_OutWritePtr      * yes. Are we at the end of the uncompressed stream?
            bne         KeepGoing@
            inc         Decomp_OutReadDone      * yes, so mark read stream as finished
 IFDEF DEBUG
            cmpy        #1                      * are there more bytes to copy?
            beq         >
            swi                                 * error: stream is at end but copy operation is not done
 ENDC
!           rts
KeepGoing@
            leay        -1,y                    * are there more bytes to copy?
            lbne        Decomp_Read_Stream      * yes, we need to reload read page and recalculate update point
            rts

* -----------------------------------------------------------------------------
* -- Local Functions
* -----------------------------------------------------------------------------

***********************************************************
* Decomp_Init_Deflate_Block:
*   Initialize a DEFLATE compression block by loading Final flag, Compression type,
*   all of the huffman code lengths, and generating the huffman trees
*
* - IN:      N/A
* - OUT:     N/A
* - TRASHED: All
***********************************************************
*
HLIT@                   zmb     1
HDIST@                  zmb     1
CodeLengthEnd@          zmb     2
*
Decomp_Init_Deflate_Block
            lda         #1                      * get the BFINAL flag
            jsr         Decomp_GetBits
            sta         Decomp_BFINAL
            lda         #2                      * get the BTYPE compression type
            jsr         Decomp_GetBits
            sta         Decomp_BTYPE
            cmpa        #2
            beq         DynamicHuffman@
            cmpa        #1
            beq         FixedHuffman@
            swi                                 * Error: block compression type is not Dynamic or Fixed Huffman
FixedHuffman@                                   * set up the code length tables for BTYPE=1 from pattern instead of reading them
            lda         #31
            sta         HLIT@                   * 288 = 257 + 31 literal codes
            sta         HDIST@                  * 32 = 1 + 31 distance codes
            ldx         #$4000+DecompData.CodeLengths
            lda         #8
            ldb         #144
!           sta         ,x+                     * first 144 code lengths are 8
            decb
            bne         <
            lda         #9
            ldb         #112
!           sta         ,x+                     * next 112 code lengths are 9
            decb
            bne         <
            lda         #7
            ldb         #24
!           sta         ,x+                     * next 24 code lengths are 7
            decb
            bne         <
            lda         #8
            ldb         #8
!           sta         ,x+                     * final 8 codes length of literal tree are also 8
            decb
            bne         <
            lda         #5
            ldb         #32
!           sta         ,x+                     * all 32 distance codes are 5 bits
            decb
            bne         <
            jmp         CreateTrees@
DynamicHuffman@
            lda         #5
            jsr         Decomp_GetBits          * Get HLIT = number of literal codes minus 257
            sta         HLIT@
            lda         #5
            jsr         Decomp_GetBits          * Get HDIST = number of distance codes minus 1
            sta         HDIST@
            lda         #4
            jsr         Decomp_GetBits          * Get HCLEN = number of Code Length codes minus 4
            adda        #4
            tfr         a,b                     * B is number of 3-bit Code Length values to read
            ldu         #$4000+DecompData.CodeLengths
            lda         #18
ClearLengths@
            clr         a,u
            deca
            bpl         ClearLengths@
            ldy         #Decomp_CodeLengthOrder
ReadLengths@
            pshs        b
            lda         #3                      * each code length value is 3 bits
            jsr         Decomp_GetBits
            ldb         ,y+                     * B is code index to write
            sta         b,u
            puls        b
            decb
            bne         ReadLengths@
            * Create huffman tree for code length values
            ldx         #19
            ldy         #$4000+DecompData.LenHuffmanTree
            jsr         Decomp_CreateHuffmanTree
            * Now we must decode the main huffman tree code lengths.  Start by figuring out
            * how many codes lengths will be needed in total
            clra
            ldb         HLIT@
            addb        HDIST@
            addd        #258+$4000+DecompData.CodeLengths
            std         CodeLengthEnd@          * pointer to address after last valid code length
            ldu         #$4000+DecompData.CodeLengths
DecodeLengths@
            ldx         #$4000+DecompData.LenHuffmanTree
            jsr         Decomp_GetHuffmanValue
            cmpb        #15
            bhi         Test16@
            stb         ,u+
            bra         DecodeLengthsTail@
Test16@     cmpb        #16
            bhi         Test17@
            lda         #2
            jsr         Decomp_GetBits
            adda        #3                      * A is number of times to copy previous code length (3-6)
            ldb         -1,u
CopyLoop1@
            stb         ,u+
            deca
            bne         CopyLoop1@
            bra         DecodeLengthsTail@
Test17@     cmpb        #17
            bhi         Test18@
            lda         #3
            jsr         Decomp_GetBits
            adda        #3                      * A is number of times to write 0 length (3-10)
            clrb
ZeroLoop1@
            stb         ,u+
            deca
            bne         ZeroLoop1@
            bra         DecodeLengthsTail@
Test18@
 IFDEF DEBUG
            cmpb        #18
            beq         >
            swi                                 * Error: illegal RLE code decoded from Code Lengths tree
 ENDC
!           lda         #7
            jsr         Decomp_GetBits
            adda        #11                     * A is number of times to write 0 length (11-138)
            clrb
ZeroLoop2@
            stb         ,u+
            deca
            bne         ZeroLoop2@
DecodeLengthsTail@
            cmpu        CodeLengthEnd@
            blo         DecodeLengths@
 IFDEF DEBUG
            beq         >
            swi                                 * Error: Code length decoding overflow
 ENDC
!           * Now create huffman tree for Literal/Length codes
CreateTrees@
            clra
            ldb         HLIT@
            addd        #257
            tfr         d,x
            pshs        d
            ldy         #$4000+DecompData.LiteralHuffmanTree
            jsr         Decomp_CreateHuffmanTree
            * move the codes for the Distance tree to the front of the code list
            puls        d
            ldu         #$4000+DecompData.CodeLengths
            leay        d,u
            clra
            ldb         HDIST@
            incb
            tfr         d,x
CopyLoop2@
            lda         ,y+
            sta         ,u+
            decb
            bne         CopyLoop2@
!           * create huffman tree for Distance codes
            ldy         #$4000+DecompData.DistHuffmanTree
            jsr         Decomp_CreateHuffmanTree
            * Both main huffman trees are now loaded; we're all done
            rts

***********************************************************
* Decomp_CreateHuffmanTree:
*   Create a canonical huffman variable-length code tree, based upon the code lengths given
*
* - IN:      X = Total number of codes
*            Y = pointer to start of tree nodes (for writing)
* - OUT:     N/A
* - TRASHED: All
***********************************************************
*
MaxCodeLength@          zmb     1
NumCodes@               zmb     2
TreeStart@              zmb     2
CodeLengthEnd@          zmb     2
NextLevelStart@         zmb     2
*
Decomp_CreateHuffmanTree
            clr         MaxCodeLength@
            stx         NumCodes@
            sty         TreeStart@
            leau        $4000+DecompData.CodeLengths,x
            stu         CodeLengthEnd@
            * start by clearing our histogram
            lda         #15
            clrb
            ldy         #$4000+DecompData.CodeCountByLength
!           stb         a,y
            deca
            bpl         <
            * now calculate the histogram (count number of codes with each length)
            * and find the maximum of all the code lengths
            ldu         #$4000+DecompData.CodeLengths
CountLengths@
            lda         ,u+
            beq         >
            inc         a,y
            cmpa        MaxCodeLength@
            bls         >
            sta         MaxCodeLength@
!           leax        -1,x
            bne         CountLengths@
            * now we fill in the tree, one level at a time
            lda         #1                      * A is the current level number
            ldx         TreeStart@              * X is current child pointer in tree level
            leay        4,x                     * Y is pointer to first node in next level
            sty         NextLevelStart@
TreeLoopOuter@
            ldu         #$4000+DecompData.CodeLengths
TreeLoopInner1@
            cmpa        ,u+                     * does this code have our current bit length?
            bne         >
            * it does, so store code value in this child pointer
            leay        -$4001-DecompData.CodeLengths,u
            sty         ,x++
!           cmpu        CodeLengthEnd@
            bne         TreeLoopInner1@
            * if we are on the last level, then break out
            cmpa        MaxCodeLength@
            beq         FinalizeTree@
            * all remaining children on this level become decision nodes and continue down 1 level
 IFDEF DEBUG
            cmpx        NextLevelStart@
            blo         >
            swi                                 * Tree generation error: tree is finished before all codes assigned
 ENDC
!           ldy         NextLevelStart@         * Y points to new decision nodes in next level
TreeLoopInner2@
            sty         ,x++
            leay        4,y
            cmpx        NextLevelStart@
            bne         TreeLoopInner2@
            * set up for the next level and jump back to outer loop start
            * X is already at correct starting location
            inca                                * Level = Level + 1
            sty         NextLevelStart@         * Y points to node after the last one in the new level
            bra         TreeLoopOuter@
FinalizeTree@
            * in case there are any unused codes, set them to -1 so we will throw SWI if we find them in bitstream
            ldd         #-1
!           cmpx        NextLevelStart@
            bhs         >
            std         ,x++
            bra         <
!           rts


***********************************************************
* Decomp_ReloadInputBuffer:
*   Load up to 256 bytes from compressed file and adjust ending pointer for
*   input buffer
*
* - IN:      N/A
* - OUT:     N/A
* - TRASHED: None
***********************************************************
*
Decomp_ReloadInputBuffer
            pshs        a,b,x,y,u
            ldd         Decomp_InFileBytesLeft
 IFDEF DEBUG
            bne         >
            swi                                 * Error: compressed stream is finished, but more bytes requested
 ENDC
!           tsta
            beq         LoadAll@
            deca                                * we will load 256 bytes
            sta         Decomp_InFileBytesLeft
            ldd         #$4000+DecompData.InBuffer+256
            std         Decomp_InBufferEnd
            ldy         #256
            bra         DoRead@
LoadAll@
            tfr         d,y                     * Y is number of bytes to load
            clr         Decomp_InFileBytesLeft+1
            addd        #$4000+DecompData.InBuffer
            std         Decomp_InBufferEnd
DoRead@
            ldu         #$4000+DecompData.InBuffer
            stu         Decomp_InCurPtr         * set input pointer to beginning of buffer
            jsr         Disk_FileRead
            lda         #1
            sta         Decomp_InBitMask        * first bit to read from input buffer
            puls        a,b,x,y,u
            rts


***********************************************************
* Decomp_ReloadOutputBuffer:
*   Decompress data from the initialized huffman streams, writing output bytes
*   to the Output buffer until the compressed stream is completely decoded or
*   the current 8k output page is completely written.
*
* - IN:      N/A
* - OUT:     N/A
* - TRASHED: All
***********************************************************
*
WritePageFinished@      zmb     1               * flag tells if we're done after a copy code is finished
CopyLen@                zmb     2
CopyDist@               zmb     2
*
Decomp_ReloadOutputBuffer
 IFDEF DEBUG
            tst         Decomp_OutWriteDone
            beq         >
            swi                                 * Error: compressed stream is finished, no more data to read
 ENDC
!           clr         WritePageFinished@
            * put page for writing at $8000
            lda         Decomp_OutBufferHandles
            ldy         #MemMgr_VirtualTable
            lda         a,y
            sta         $FFA4
            ldu         Decomp_OutWritePtr
DecodeLoop@
            * Get literal/length code
            ldx         #$4000+DecompData.LiteralHuffmanTree
            jsr         Decomp_GetHuffmanValue
            tsta
            bne         SpecialCode@
            * < 256 is a Literal code
            stb         ,u+
            cmpu        #$A000
            bne         DecodeLoop@
            * this page is finished. Move all pages down, and recycle oldest page to new slot
            ldd         #$8000
            std         Decomp_OutWritePtr
            lda         Decomp_OutBufferHandles+4
            ldb         Decomp_OutBufferHandles
            sta         Decomp_OutBufferHandles
            lda         Decomp_OutBufferHandles+1
            stb         Decomp_OutBufferHandles+1
            ldb         Decomp_OutBufferHandles+2
            sta         Decomp_OutBufferHandles+2
            lda         Decomp_OutBufferHandles+3
            stb         Decomp_OutBufferHandles+3
            sta         Decomp_OutBufferHandles+4
            inc         Decomp_OutReadPage      * increment page index for read pointer
            rts
SpecialCode@
            cmpd        #256
            bne         CopyCode@
            * 256 is End of Stream code
            tst         Decomp_BFINAL           * is there another block left?
            bne         >
            pshs        u                       * this was not final block, so initialize another block
            jsr         Decomp_Init_Deflate_Block
            puls        u                       * continue decoding with new block until page or stream is finished
            bra         DecodeLoop@
!           inc         Decomp_OutWriteDone     * this was the last compressed block, so output writing is done
            stu         Decomp_OutWritePtr
            rts
CopyCode@
            * first we need to calculate the length to copy
            cmpd        #264
            bhi         >
            subd        #254                    * no extra bits required; length is in D
            bra         GetDistance@
!           subd        #265
            cmpb        #20
            bne         >                       * 285 is special case (length=258)
            ldd         #258
            bra         GetDistance@
!           tfr         b,a
            lsra
            lsra
            inca                                * A is number of extra Length bits to read from raw bitstream
            andb        #3
            pshs        d
            jsr         Decomp_GetBits
            tfr         a,b
            addb        #3
            clra
            tfr         d,x                     * X is value in extra bits loaded from bitstream + 3
            puls        d
            addb        #4
!           lslb
            deca
            bne         <
            abx                                 * this must be 'abx' because B can be up to 224 and must be unsigned
            tfr         x,d
GetDistance@
            std         CopyLen@                * save length for later
            ldx         #$4000+DecompData.DistHuffmanTree
            jsr         Decomp_GetHuffmanValue
            cmpb        #3
            bhi         >
            incb
            bra         DoCopy@
!           subb        #4
            tfr         b,a
            lsra
            inca                                * A is number of extra Distance bits to read from raw bitstream
            sta         ldx_NumExtraBits@+2
            andb        #1
            pshs        b
            jsr         Decomp_GetBits16
            INCREMENT_D
            std         addd_DistRawValue@+1    * D is value in extra bits loaded from bitstream + 1 (range 1-8192)
            clra
            puls        b
            addb        #2
ldx_NumExtraBits@
            ldx         #0                      * SMC: number of extra bits in this code was inserted above
!           lslb
            rola
            leax        -1,x
            bne         <
addd_DistRawValue@
            addd        #0                      * SMC: value added to D was read from raw bitstream and inserted above
DoCopy@
            std         CopyDist@
            * calculate starting page index and pointer for copy operation source
            tfr         u,d
            subd        CopyDist@
            tfr         d,x                     * X will become the pointer
            clra                                * A is source page index
!           cmpx        #$8000
            bhs         >
            inca
            leax        $2000,x
            bra         <
!           leax        -$2000,x                * adjust X to be in historical page $6000-$7FFF location
            ldy         #Decomp_OutBufferHandles
            ldb         a,y
            ldy         #MemMgr_VirtualTable
            ldb         b,y
            stb         $FFA3                   * map historical data page to $6000 page
            ldy         CopyLen@                * Y is number of bytes to copy
CopyLoop@
            ldb         ,x+                     * copy one byte
            stb         ,u+
            * handle historical data page overflow
            cmpx        #$8000
            blo         CheckWritePage@
            deca                                * move up to newer page
 IFDEF DEBUG
            bpl         >
            swi                                 * it should be impossible for historical data page index to go negative
 ENDC
!           pshs        y                       * save remaining byte counter
            ldy         #Decomp_OutBufferHandles
            ldb         a,y
            ldy         #MemMgr_VirtualTable
            ldb         b,y
            stb         $FFA3                   * map historical data page to $6000 page
            puls        y
            ldx         #$6000
            * handle current write page overflow
CheckWritePage@
            cmpu        #$A000
            blo         CopyLoopTail@
            * this page is finished. Move all pages down, and recycle oldest page to new slot
            pshs        a,y
            lda         Decomp_OutBufferHandles+4
            ldb         Decomp_OutBufferHandles
            sta         Decomp_OutBufferHandles
            lda         Decomp_OutBufferHandles+1
            stb         Decomp_OutBufferHandles+1
            ldb         Decomp_OutBufferHandles+2
            sta         Decomp_OutBufferHandles+2
            lda         Decomp_OutBufferHandles+3
            stb         Decomp_OutBufferHandles+3
            sta         Decomp_OutBufferHandles+4
            inc         Decomp_OutReadPage      * increment page index for read pointer
            ldb         Decomp_OutBufferHandles * B is new page handle to write
            ldy         #MemMgr_VirtualTable
            ldb         b,y
            stb         $FFA4                   * map write data page to $8000
            puls        a,y
            inca
            ldu         #$8000
            inc         WritePageFinished@      * we finished writing the page, so exit after this copy is completed
CopyLoopTail@
            leay        -1,y                    * loop until all bytes copied
            bne         CopyLoop@
            tst         WritePageFinished@      * if we didn't cross a page boundary during this copy
            lbeq        DecodeLoop@             * then continue with the next literal/length huffman code
            stu         Decomp_OutWritePtr      * otherwise we're done
            rts

***********************************************************
* Decomp_GetHuffmanValue:
*   Retrieve one bit at a time, traversing a Huffman tree until
*   a code is found
*
* - IN:      X = pointer to root node of huffman tree
* - OUT:     D = value decoded from input bitstream
* - TRASHED: X,Y
***********************************************************
*
Decomp_GetHuffmanValue
            ldy         Decomp_InCurPtr
            lda         Decomp_InBitMask
BitLoop@
            * load in one bit and get literal value or link to next huffman node
            bita        ,y
            beq         >
            ldx         2,x                     * follow right child link
            bra         BitLinkDone@
!           ldx         ,x
BitLinkDone@
 IFDEF DEBUG
            bpl         >
            swi                                 * Error: invalid huffman code found in bitstream
 ENDC
            * update bit reading state variables and load more data if necessary
!           lsla
            bne         BitLoopTail@
            lda         #1                      * start on LSB of next byte
            leay        1,y
            cmpy        Decomp_InBufferEnd      * are we at the end of the input buffer?
            bne         BitLoopTail@
            cmpx        #256                    * yes.  did we just decode a STOP code?
            bne         >
            ldd         #256                    * we did, so don't update the bit pointers, just return 256
            rts
!           jsr         Decomp_ReloadInputBuffer    * no STOP code, so load more input data
            ldy         #$4000+DecompData.InBuffer
BitLoopTail@                                    * if new pointer is a decision node, then loop again
            cmpx        #512                    * theoretically 285 is the max possible huffman code value
            bhs         BitLoop@
            cmpx        #256
            beq         >                       * if we get a STOP code, don't update the bit pointers
            sta         Decomp_InBitMask        * so if a bug in client calls us multiple times, we
            sty         Decomp_InCurPtr         * will keep returning STOP
!           tfr         x,d                     * put return value into D
            rts


***********************************************************
* Decomp_GetBits16:
*   Retrieve a variable number of bits (1-16) from the input bitstream,
*   filling in the lowest bits first
*
* - IN:      A = Number of bits to retrieve (1-16)
* - OUT:     D = value retrieved from bitstream (right-aligned)
* - TRASHED: X
***********************************************************
*
Decomp_GetBits16
            cmpa        #8
            bhi         TwoGets@
            jsr         Decomp_GetBits
            tfr         a,b
            clra
            rts
TwoGets@
            suba        #8
            sta         lda_BitsRemaining@+1
            lda         #8                      * get 8 bits in low byte
            jsr         Decomp_GetBits
            pshs        a
lda_BitsRemaining@
            lda         #0                      * SMC: number of bits to retrieve in high byte is written above
            jsr         Decomp_GetBits          * get bits in high byte
            puls        b
            rts

***********************************************************
* Decomp_GetBits:
*   Retrieve a variable number of bits (1-8) from the input bitstream,
*   filling in the lowest bits first
*
* - IN:      A = Number of bits to retrieve (1-8)
* - OUT:     A = value retrieved from bitstream (right-aligned)
* - TRASHED: B,X
***********************************************************
*
BitsLeft@               zmb         1
ReturnValue@            zmb         1
*
Decomp_GetBits
            sta         BitsLeft@
            clr         ReturnValue@
            ldx         Decomp_InCurPtr
            lda         Decomp_InBitMask
            ldb         #1                      * non-code values are stored with LSB first
BitLoop@
            bita        ,x
            beq         >
            pshs        b
            orb         ReturnValue@
            stb         ReturnValue@
            puls        b
!           lslb
            lsla
            bne         BitLoopTail@
            lda         #1                      * start on LSB of next byte
            leax        1,x
            cmpx        Decomp_InBufferEnd
            bne         >
            jsr         Decomp_ReloadInputBuffer
            ldx         #$4000+DecompData.InBuffer
!           stx         Decomp_InCurPtr
BitLoopTail@
            dec         BitsLeft@
            bne         BitLoop@
            sta         Decomp_InBitMask
            lda         ReturnValue@
            rts


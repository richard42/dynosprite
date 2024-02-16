*********************************************************************************
* DynoSprite - disk.asm
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

DC          STRUCT
OPC                     rmb     1
DRV                     rmb     1
TRK                     rmb     1
SEC                     rmb     1
BPT                     rmb     2
STA                     rmb     1
            ENDSTRUCT


***********************************************************
* Disk_DirInit:
*   We read and cache the disk 0 directory and FAT in this function,
*   for later use by the file handling functions
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X,Y,U
***********************************************************
Disk_DirInit
            ldx         $C006                   * get pointer to DSKCON parameter block
            lda         #2
            sta         DC.OPC,x                * Operation Code == Read sector 
            * we won't set the drive # here, so that we will load everything from the
            * most recently accessed drive (which loaded this program, so should contain our data)
            lda         #17
            sta         DC.TRK,x                * Track 17 (directory track)
            lda         #2
            sta         DC.SEC,x                * Sector 2 (FAT)
            ldd         #Disk_DirSector
            std         DC.BPT,x                * Sector Buffer == DiskDirSector
            jsr         System_CallDSKCON
!           ldy         #Disk_FAT
            ldu         #Disk_DirSector
            ldb         #68
!           lda         ,u+                     * copy 68 bytes of FAT into destination table
            sta         ,y+
            decb
            bne         <
            lda         #3
            sta         DC.SEC,x                * sector 3 (first 8 directory entries)
            sta         Disk_DirSectorNum
            jsr         System_CallDSKCON
            clr         $FF40                   * turn off drive motor
            clr         $986                    * clear DGRAM also, so Disk BASIC knows that drive motor was shut off
            rts

***********************************************************
* Disk_FileOpen:
*   We search for the given filename in the directory, and
*   set initial parameters in our data structures
*
* - IN:      X = Pointer to filename (11 characters, no extension separator)
* - OUT:     N/A
* - Trashed: A,B,U
***********************************************************
DirSecLeft@ zmb         1
Disk_FileOpen
 IFDEF DEBUG
            lda         Disk_FileIsOpen
            beq         >
            swi                                 * error, previous file was not closed
 ENDC
!           lda         #9                      * maximum number of directory sectors to search (3-11)
            sta         DirSecLeft@
SearchDirSector@
            ldu         #Disk_DirSector         * search for matching filename
FindMatch@  pshs        x,u
            ldb         #11
!           lda         ,u+
            cmpa        ,x+
            bne         DirEntryNoMatch@
            decb
            beq         DirEntryMatch@
            bra         <
DirEntryNoMatch@
            puls        x,u
            leau        32,u                    * go to next directory entry
            cmpu        #Disk_DirSector+256
            blo         FindMatch@
SectorNoMatch@
            dec         DirSecLeft@
            bne         LoadNextDirSector@
            swi                                 * Error: file not found in 72 directory entries
LoadNextDirSector@
            pshs        x
            ldx         $C006                   * get pointer to DSKCON parameter block
            lda         #2
            sta         DC.OPC,x                * Operation Code == Read sector
            * we won't set the drive # here, so that we will load everything from the
            * most recently accessed drive (which loaded this program, so should contain our data)
            lda         #17
            sta         DC.TRK,x                * Track 17 (directory track)
            lda         Disk_DirSectorNum
            inca                                * advance to next directory sector
            cmpa        #12
            blo         >
            lda         #3                      * wrap around from 12 to 3
!           sta         Disk_DirSectorNum
            sta         DC.SEC,x                * Directory Sector Number
            ldd         #Disk_DirSector
            std         DC.BPT,x                * Sector Buffer == DiskDirSector
            jsr         System_CallDSKCON       * read sector
            puls        x
            bra         SearchDirSector@        * go look through the directory entries in the newly loaded sector
DirEntryMatch@
            puls        x,u
 IFDEF DEBUG
            inc         Disk_FileIsOpen
            clr         Disk_FileAtEnd
 ENDC
            * store starting location
            lda         13,u                    * First granule in file
            sta         Disk_FileCurGranule
            tfr         a,b
            lsra
            cmpa        #17
            blo         >
            inca
!           sta         Disk_FileCurTrack
            andb        #1
            lda         #9
            mul
            incb
            stb         Disk_FileCurSector
            clr         Disk_FileCurByte
            * calculate and store number of granules and sectors remaining
            ldd         14,u                    * number of bytes in use in last sector of file
            std         Disk_FileBytesInLastSec
            ldu         #Disk_FAT
            clr         Disk_FileGranulesLeft
            ldd         #$900                   * assume the file is at least 1 granule long
            std         Disk_FileBytesInCurGran
            ldb         Disk_FileCurGranule
FileLengthLoop@
            lda         b,u
 IFDEF DEBUG
            cmpa        #$ff
            bne         >
            swi                                 * error in FAT: file points to empty granule
 ENDC
!           cmpa        #$C0
            bhs         LastGranule@
            inc         Disk_FileGranulesLeft
            tfr         a,b
            bra         FileLengthLoop@
LastGranule@
            tst         Disk_FileGranulesLeft   * is this file > 1 granule?
            bne         >
            anda        #$1f                    * no, so calculate size of current (final) granule
            clrb
            addd        Disk_FileBytesInLastSec
            deca
            std         Disk_FileBytesInCurGran
!           rts

***********************************************************
* Disk_FileSeekForward:
*
* - IN:      D = distance to seek in bytes
* - OUT:     N/A
* - Trashed: A,B,X,U
***********************************************************
*
SeekDistance@           rmd 1
*
Disk_FileSeekForward
            std         SeekDistance@
            bne         NonZeroSeek@
            rts                                 * seek 0 is NOP
NonZeroSeek@
 IFDEF DEBUG
            tst         Disk_FileAtEnd
            beq         >
            swi                                 * seek past end of file
!           tst         Disk_FileIsOpen
            bne         >
            swi                                 * error, file is not open
 ENDC
!           cmpd        Disk_FileBytesInCurGran * is the seeking end point in this granule?
            bhs         NotInThisGranule@
            * update counter of remaining bytes in current granule
            ldd         Disk_FileBytesInCurGran
            subd        SeekDistance@
            std         Disk_FileBytesInCurGran
            * update current sector/byte
            ldd         SeekDistance@
            addd        Disk_FileCurSector      * updated sector/byte location
            std         Disk_FileCurSector
            rts
NotInThisGranule@
            subd        Disk_FileBytesInCurGran * D is remaining bytes to seek forward after current granule
            tst         Disk_FileGranulesLeft   * are there any remaining granules in this file?
            bne         SeekNextGranule@
            cmpd        #0                      * no granules left, so we better be at end of file
            beq         >
            swi                                 * Error: seek past end of file
 IFDEF DEBUG
!           inc         Disk_FileAtEnd
 ENDC
!           rts
SeekNextGranule@
            tfr         d,x                     * X = bytes to seek forward, starting w/ next granule
            lda         Disk_FileCurGranule
            ldu         #Disk_FAT
GetFATEntry@
            ldb         a,u                     * Get next granule
            dec         Disk_FileGranulesLeft
            cmpx        #$900                   * is the seek end point in this granule?
            blo         InThisGranule@
 IFDEF DEBUG
            cmpb        #$C0
            blo         >
            swi                                 * Error: seek past end of file
 ENDC
!           leax        -$900,x
            tfr         b,a
            bra         GetFATEntry@
InThisGranule@
            stx         SeekDistance@           * save the offset to seek within this granule
            stb         Disk_FileCurGranule     * B contains the granule number which includes our seek end point
            pshs        b
            lda         b,u
            cmpa        #$C0                    * is this granule full?
            blo         >
            anda        #$1F                    * no, it is partial, so calculate # of bytes in last granule
            clrb
            addd        Disk_FileBytesInLastSec
            deca
            bra         ReCalcPosition@
!           ldd         #$900
ReCalcPosition@
            subd        SeekDistance@
 IFDEF DEBUG
            bhs         >
            swi                                 * Error: seek past end of file
 ENDC
!           std         Disk_FileBytesInCurGran * bytes remaining in current granule after seek operation
            lda         ,s
            lsra
            cmpa        #17
            blo         >
            inca
!           sta         Disk_FileCurTrack
            puls        a
            anda        #1
            eora        #1
            deca
            anda        #9
            inca                                * B is starting sector # of new granule
            clrb
            addd        SeekDistance@           * D is final sector/byte of file pointer after seeking
            std         Disk_FileCurSector
            rts

***********************************************************
* Disk_FileRead:
*
* - IN:      Y = number of bytes to read, U = pointer to buffer to load data
* - OUT:     N/A
* - Trashed: A,B,X,Y,U
***********************************************************

Disk_FileRead
            cmpy        #0
            bne         NonZeroRead@
            rts                                 * read 0 bytes is NOP
NonZeroRead@
 IFDEF DEBUG
            tst         Disk_FileIsOpen
            bne         >
            swi                                 * error, no file is open
!           tst         Disk_FileAtEnd
            beq         >
            swi                                 * Error: file is already at end
 ENDC
!           ldx         Disk_FileCurTrack       * current file location
            cmpx        Disk_CachedTrackIdx     * do we already have this sector in disk cache?
            beq         >
            pshs        y,u
            jsr         Disk_ReadSector         * no, so go read this sector
            puls        y,u
!           ldx         #Disk_CacheSector
            ldb         Disk_FileCurByte
            abx
            clrb                                * B is negative counter of bytes copied
CopyLoop@   lda         ,x+
            sta         ,u+
            decb
            cmpx        #Disk_CacheSector+256   * did we just read the last byte in cached sector?
            beq         ReadNextSector@
            leay        -1,y
            bne         CopyLoop@               * continue until no bytes remaining to copy
            lda         #$ff                    * D is negative number of bytes copied from this sector
            addd        Disk_FileBytesInCurGran
 IFDEF DEBUG
            bpl         >
            swi                                 * Error: read past end of file
 ENDC
!           std         Disk_FileBytesInCurGran
            tfr         x,d
            subd        #Disk_CacheSector
            stb         Disk_FileCurByte        * update byte offset in current sector
            rts
ReadNextSector@
            clr         Disk_FileCurByte        * next copy will start at beginning of sector
            lda         #$ff                    * D is negative number of bytes copied from this sector
            addd        Disk_FileBytesInCurGran
 IFDEF DEBUG
            bpl         >
            swi                                 * Error: read past end of file
 ENDC
!           std         Disk_FileBytesInCurGran
            beq         ReadNextGranule@
            inc         Disk_FileCurSector      * read next sector
            pshs        u,y
            jsr         Disk_ReadSector
            puls        u,y
            leay        -1,y                    * update bytes remaining to copy
            bne         >
            rts                                 * all done, new sector is in cache with 256 bytes unread
!           ldx         #Disk_CacheSector
            clrb
            bra         CopyLoop@
ReadNextGranule@
            pshs        u,y
            lda         Disk_FileCurGranule
            ldu         #Disk_FAT
            ldb         a,u                     * B is next granule number
            cmpb        #$C0
            blo         NextGranValid@
 IFDEF DEBUG
            cmpy        #1                      * Previous granule was last one, so we better be done copying
            beq         >
            swi                                 * Error: read past end of file
!           inc         Disk_FileAtEnd
 ENDC
            rts
NextGranValid@
            stb         Disk_FileCurGranule
            dec         Disk_FileGranulesLeft
 IFDEF DEBUG
            bpl         >
            swi                                 * Error: broken FAT or internal logic
 ENDC
!           pshs        b
            lda         b,u
            cmpa        #$C0                    * is this granule full?
            blo         >
            anda        #$1F                    * no, it is partial, so calculate # of bytes in last granule
            clrb
            addd        Disk_FileBytesInLastSec
            deca
            bra         StoreNewGranSize@
!           ldd         #$900
StoreNewGranSize@
            std         Disk_FileBytesInCurGran * bytes remaining in new granule
            lda         ,s
            lsra
            cmpa        #17
            blo         >
            inca
!           sta         Disk_FileCurTrack
            puls        a
            anda        #1
            ldb         #9
            mul
            incb                                * B is starting sector # of new granule
            stb         Disk_FileCurSector
            jsr         Disk_ReadSector         * read first sector in new granule
            puls        u,y
            leay        -1,y                    * update bytes remaining to copy
            bne         >
            rts                                 * all done, new sector is in cache with 256 bytes unread
!           ldx         #Disk_CacheSector
            clrb
            jmp         CopyLoop@

Disk_ReadSector
            ldx         $C006                   * get pointer to DSKCON parameter block
            lda         #2
            sta         DC.OPC,x                * Operation Code == Read sector
            lda         Disk_FileCurTrack
            sta         Disk_CachedTrackIdx
            sta         DC.TRK,x                * Track
            lda         Disk_FileCurSector
            sta         Disk_CachedSectorIdx
            sta         DC.SEC,x                * Sector
            ldd         #Disk_CacheSector
            std         DC.BPT,x                * Sector Buffer == Disk_CacheSector
            jsr         System_CallDSKCON       * read current sector
            ldx         Disk_ProgressCallback   * send progress callback after every sector read
            beq         >
            jmp         ,x
!           rts

***********************************************************
* Disk_FileClose:
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: None
***********************************************************
Disk_FileClose
 IFDEF DEBUG
            tst         Disk_FileIsOpen
            bne         >
            swi                                 * error, no file is open
!           clr         Disk_FileIsOpen
 ENDC
            clr         $FF40                   * turn off drive motor
            clr         $986                    * clear DGRAM also, so Disk BASIC knows that drive motor was shut off
            rts

***********************************************************
* Disk_SetProgressCallback:
*
* - IN:      X = address of callback function (or NULL)
* - OUT:     N/A
* - Trashed: None
***********************************************************
Disk_SetProgressCallback
            stx         Disk_ProgressCallback
            rts



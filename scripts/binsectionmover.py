#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/binsectionmover.py
# Copyright (c) 2013-2014, Richard Goedeken
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#********************************************************************************

import sys

def FilterFile(Filename, FilterList):
    print "Filtering BIN file section locations: %s" % Filename
    fIn = open(Filename, "rb").read()
    fOut = ""
    curIdx = 0
    while True:
        if curIdx >= len(fIn):
            print "Error in BIN file: no postamble"
            return -1
        flag = ord(fIn[curIdx])
        curIdx += 1
        if flag == 0:
            length = ord(fIn[curIdx]) * 256 + ord(fIn[curIdx+1])
            loadAddr = ord(fIn[curIdx+2]) * 256 + ord(fIn[curIdx+3])
            curIdx += 4
            bMoved = False
            for (oldStart, oldEnd, newStart) in FilterList:
                if loadAddr >= oldStart and loadAddr <= oldEnd:
                    bMoved = True
                    newLoadAddr = loadAddr + newStart - oldStart
                    print "Section (%04x-%04x) is moved to %04x" % (loadAddr, loadAddr+length-1, newLoadAddr)
                    loadAddr = newLoadAddr
                    break
            if not bMoved:
                print "Section (%04x-%04x) is not moved" % (loadAddr, loadAddr+length-1)
            fOut = fOut + chr(0) + chr(length >> 8) + chr(length & 0xff) + chr(loadAddr >> 8) + chr(loadAddr & 0xff)
            fOut = fOut + fIn[curIdx:curIdx+length]
            curIdx += length
            continue
        elif flag == 255:
            zeros = ord(fIn[curIdx]) * 256 + ord(fIn[curIdx+1])
            execAddr = ord(fIn[curIdx+2]) * 256 + ord(fIn[curIdx+3])
            curIdx += 4
            if zeros != 0:
                print "Error: values in postamble which should be zero are %04x" % zeros
                return -3
            print "Postamble section found with execution address %04x" % execAddr
            fOut = fOut + chr(255) + chr(0) + chr(0) + chr(execAddr >> 8) + chr(execAddr & 0xff)
            if curIdx != len(fIn):
                print "Error: %i extra bytes after postamble in BIN file" % (len(fIn)-curIdx)
                return -4
            break
        else:
            print "Error in BIN file: section start flag value is %02x" % flag
            return -2
    if len(fOut) != len(fIn):
        print "Internal error: output length doesn't match input length"
        return -5
    open(Filename, "wb").write(fOut)
    print "Success!"

#******************************************************************************
# main function call for standard script execution
#

if __name__ == "__main__":
    if len(sys.argv) < 4 or (len(sys.argv) & 1) != 0:
        print "Usage: %s <filename.bin> [(OldStart-OldEnd) NewStart] ..." % sys.argv[0]
        sys.exit(1)
    Filename = sys.argv[1]
    AddrFilters = []
    for i in range(2,len(sys.argv),2):
        oldRange = sys.argv[i].split('-')
        if len(oldRange) != 2:
            print "Error: invalid range %s" % sys.argv[i]
        oldStart = int(oldRange[0], 16)
        oldEnd = int(oldRange[1], 16)
        newStart = int(sys.argv[i+1], 16)
        AddrFilters.append((oldStart, oldEnd, newStart))
    FilterFile(Filename, AddrFilters)


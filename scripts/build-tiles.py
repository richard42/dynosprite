#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/build-tiles.py
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

import os
import sys
from compression import *

class Tileset:
    def __init__(self, filename):
        self.filename = filename
        self.number = int(filename[:2])
        self.palettes = [ None, None ]
        self.tiles = [ ]
    def validate(self):
        palNames = [ "Composite", "RGB" ]
        # check palette arrays
        for p in range(2):
            if self.palettes[p] == None:
                print "****Error: missing %s palette in tileset '%s'" % (palNames[p], self.filename)
                return False
            if len(self.palettes[p]) != 16:
                print "****Error: %s palette length is %i (should be 16) in tileset '%s'" % (palNames[p], len(self.palettes[p]), self.filename)
                return False
            for i in range(16):
                clrIdx = self.palettes[p][i]
                if clrIdx < 0 or clrIdx > 63:
                    print "****Error: invalid color value %i in %s palette in tileset '%s'" % (clrIdx, palNames[p], self.filename)
                    return False
        # check each tile
        numTiles = len(self.tiles)
        for i in range(numTiles):
            tile = self.tiles[i]
            if len(tile) != 128:
                print "****Error: invalid data length %i (should be 128) for tile %i in tileset '%s'" % (len(tile), i, self.filename)
                return False
            for pixVal in tile:
                if pixVal < 0 or pixVal > 255:
                    print "****Error: invalid pixel value %i in tile %i in tileset '%s'" % (pixVal, i, self.filename)
                    return False
        return True

def SaveMatrix(tileset, section, matrix):
    if section == "palette-cmp":
        tileset.palettes[0] = matrix
    elif section == "palette-rgb":
        tileset.palettes[1] = matrix
    elif section == "tiles":
        tileset.tiles.append(matrix)
    elif mode != None:
        print "****Error: Invalid section '%s' in tileset file '%s'" % (section, tileset.filename)
        sys.exit(1)
    return

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print "DynoSprite Tile Builder script"
    # get input paths
    if len(sys.argv) != 4:
        print "****Usage: %s <in_tile_folder> <out_cc3_folder> <out_asm_folder>" % sys.argv[0]
        sys.exit(1)
    tiledir = sys.argv[1]
    cc3dir = sys.argv[2]
    asmdir = sys.argv[3]
    # make list of tile description files found
    filelist = os.listdir(tiledir)
    filelist = [name for name in filelist if len(name) >= 6 and name[:2].isdigit() and name[-4:].lower() == ".txt"]
    filelist.sort()
    print "    Found %i tilesets" % len(filelist)
    # parse each file
    tilesets = []
    for filename in filelist:
        f = open(os.path.join(tiledir, filename), "r").read()
        mode = None
        curSet = Tileset(filename)
        matrix = [ ]
        for line in f.split("\n"):
            # remove comments and whitespace from line
            pivot = line.find("*")
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
                continue
            # handle new sections
            if len(line) > 2 and line[0] == '[' and line[-1] == ']':
                # save previous matrix
                SaveMatrix(curSet, mode, matrix)
                # start a new section
                mode = line[1:-1].lower()
                matrix = [ ]
                continue
            # handle palette values (decimal)
            if mode != None and len(mode) > 7 and mode[:7] == "palette":
                newvalues = [int(v) for v in line.split()]
                matrix.extend(newvalues)
                continue
            # handle tile pixel values (hex)
            pix = "".join(line.split())
            if (len(pix) & 1) == 1:
                print "****Error: invalid tile pixel line length (%i) in tileset '%s'" % (len(pix), filename)
                sys.exit(1)
            for i in range(0, len(pix), 2):
                v = int(pix[i:i+2], 16)
                matrix.append(v)
            if len(matrix) == 128:
                curSet.tiles.append(matrix)
                matrix = [ ]
            continue
        # save any previous matrix being defined at end of file
        if len(matrix) > 0:
            SaveMatrix(curSet, mode, matrix)
        # validate this tileset
        if not curSet.validate():
            sys.exit(1)
        # add this tileset to our list
        tilesets.append(curSet)
    # print summary
    totalTiles = 0
    for curSet in tilesets:
        totalTiles += len(curSet.tiles)
    print "    Found a total of %i tiles" % (totalTiles)
    # write out the data file
    f = open(os.path.join(cc3dir, "TILES.DAT"), "wb")
    compressedTilesetLength = [ ]
    for curSet in tilesets:
        for pal in curSet.palettes:
            for i in range(16):
                f.write(chr(pal[i]))
        rawData = ""
        for tile in curSet.tiles:
            for i in range(128):
                rawData += chr(tile[i])
        comp = Compressor(rawData)
        zipData = comp.Deflate(bPrintInfo=False, bUseGzip=True)
        compressedTilesetLength.append(len(zipData))
        f.write(zipData)
    f.close()
    # write tile directory table to include in DynoSprite core
    f = open(os.path.join(asmdir, "gamedir-tiles.asm"), "w")
    f.write("Gamedir_Tiles\n")
    s = str(len(tilesets))
    f.write((" " * 24) + "fcb     " + s + (" " * (16 - len(s))) + "* number of tilesets\n")
    for i in range(len(tilesets)):
        f.write((" " * 24) + "* " + tilesets[i].filename + "\n")
        s = str(tilesets[i].number)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* tileset number\n")
        s = str(len(tilesets[i].tiles))
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* number of tiles in tileset\n")
        s = str(compressedTilesetLength[i])
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* compressed tileset size on disk in bytes\n")
    f.close()



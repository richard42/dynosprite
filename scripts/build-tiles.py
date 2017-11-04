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
    def __init__(self, palfilename, tilesetfilename, tilemaskfilename):
        self.palfilename = palfilename
        self.tilesetfilename = tilesetfilename
        self.tilemaskfilename = tilemaskfilename
        self.number = int(tilesetfilename[7:9])
        self.palettes = [ None, None ]
        self.collisionTable = None
        self.tiles = [ ]
        self.masks = [ ]
    def validate(self):
        palNames = [ "Composite", "RGB" ]
        # check palette arrays
        for p in range(2):
            if self.palettes[p] == None:
                print "****Error: missing %s palette in file '%s'" % (palNames[p], self.palfilename)
                return False
            if len(self.palettes[p]) != 16:
                print "****Error: %s palette length is %i (should be 16) in file '%s'" % (palNames[p], len(self.palettes[p]), self.palfilename)
                return False
            for i in range(16):
                clrIdx = self.palettes[p][i]
                if clrIdx < 0 or clrIdx > 63:
                    print "****Error: invalid color value %i in %s palette in file '%s'" % (clrIdx, palNames[p], self.palfilename)
                    return False
        # check each tile
        numTiles = len(self.tiles)
        for i in range(numTiles):
            tile = self.tiles[i]
            if len(tile) != 128:
                print "****Error: invalid data length %i (should be 128) for tile %i in tileset '%s'" % (len(tile), i, self.tilesetfilename)
                return False
            for pixVal in tile:
                if pixVal < 0 or pixVal > 255:
                    print "****Error: invalid pixel value %i in tile %i in tileset '%s'" % (pixVal, i, self.tilesetfilename)
                    return False
        # check collision table
        numMasks = len(self.masks)
        if len(self.collisionTable) != numTiles:
            print "****Error: Collision table length (%i) and number of tiles (%i) don't match in tileset '%s'" % (len(self.collisionTable), numTiles, self.tilesetfilename)
            return False
        for i in range(numTiles):
            collVal = self.collisionTable[i]
            if collVal < 0 or (collVal != 255 and collVal > numMasks):
                print "****Error: Invalid value (%i) in Collision Table in tilemask '%s'" % (collVal, self.tilemaskfilename)
                return False
        # check each mask
        for i in range(numMasks):
            mask = self.masks[i]
            if len(mask) != 128:
                print "****Error: invalid data length %i (should be 128) for mask %i in tilemask '%s'" % (len(mask), i, self.tilemaskfilename)
                return False
            for pixVal in mask:
                if pixVal < 0 or pixVal > 255:
                    print "****Error: invalid pixel value %i in mask %i in tilemask '%s'" % (pixVal, i, self.tilemaskfilename)
                    return False
        return True

def SaveMatrix(tileset, section, matrix):
    if section == "palette-cmp":
        tileset.palettes[0] = matrix
    elif section == "palette-rgb":
        tileset.palettes[1] = matrix
    elif section != None:
        print "****Error: Invalid section '%s' in palette file '%s'" % (section, tileset.palfilename)
        sys.exit(1)
    return

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print "DynoSprite Tile Builder script"
    # get input paths
    if len(sys.argv) != 5:
        print "****Usage: %s <in_gfx_folder> <in_buildobj_folder> <out_cc3_folder> <out_asm_folder>" % sys.argv[0]
        sys.exit(1)
    gfxdir = sys.argv[1]
    buildobjdir = sys.argv[2]
    cc3dir = sys.argv[3]
    asmdir = sys.argv[4]
    # make list of tileset and palette files found
    filelist = os.listdir(gfxdir)
    setnames = [name[7:-4] for name in filelist if len(name) >= 15 and name[:7] == 'tileset' and name[7:9].isdigit() and name[-4:].lower() == ".txt"]
    setnames.sort()
    print "    Found %i tilesets" % len(setnames)
    # parse each tileset/palette file pair
    tilesets = []
    for tilesetprefix in setnames:
        tilesetfilename = "tileset%s.txt" % tilesetprefix
        tilemaskfilename = "tilemask%s.txt" % tilesetprefix
        palettefilename = "palette%s.txt" % tilesetprefix
        if not os.path.exists(os.path.join(gfxdir, palettefilename)):
            print "****Error: Matching palette file '%s' not found!" % palettefilename
            sys.exit(1)
        if not os.path.exists(os.path.join(gfxdir, tilemaskfilename)):
            print "****Error: Matching tilemask file '%s' not found!" % tilemaskfilename
            sys.exit(1)
        mode = None
        curSet = Tileset(palettefilename, tilesetfilename, tilemaskfilename)
        # load palettes
        f = open(os.path.join(gfxdir, palettefilename), "r").read()
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
            newvalues = [int(v) for v in line.split()]
            matrix.extend(newvalues)
        # save last matrix
        if len(matrix) > 0:
            SaveMatrix(curSet, mode, matrix)
        # load tiles
        f = open(os.path.join(gfxdir, tilesetfilename), "r").read()
        matrix = [ ]
        for line in f.split("\n"):
            # remove comments and whitespace from line
            pivot = line.find("*")
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
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
        # load masks
        f = open(os.path.join(gfxdir, tilemaskfilename), "r").read()
        matrix = [ ]
        for line in f.split("\n"):
            # remove comments and whitespace from line
            pivot = line.find("*")
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
                continue
            # handle collision table
            if curSet.collisionTable is None:
                curSet.collisionTable = [ int(n.strip()) for n in line.split(",") ]
                continue
            # handle tile mask values (hex)
            pix = "".join(line.split())
            if (len(pix) & 1) == 1:
                print "****Error: invalid tile mask line length (%i) in tilemask '%s'" % (len(pix), tilemaskfilename)
                sys.exit(1)
            for i in range(0, len(pix), 2):
                v = int(pix[i:i+2], 16)
                matrix.append(v)
            if len(matrix) == 128:
                curSet.masks.append(matrix)
                matrix = [ ]
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
        for i in range(len(curSet.collisionTable)):
            rawData += chr(curSet.collisionTable[i])
        for tile in curSet.tiles:
            for i in range(128):
                rawData += chr(tile[i])
        for mask in curSet.masks:
            for i in range(128):
                rawData += chr(mask[i])
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
        f.write((" " * 24) + "* " + tilesets[i].tilesetfilename + "\n")
        s = str(tilesets[i].number)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* tileset number\n")
        s = str(len(tilesets[i].tiles))
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* number of tiles in tileset\n")
        s = str(len(tilesets[i].masks))
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* number of masks in tilemask\n")
        s = str(compressedTilesetLength[i])
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* compressed tileset size on disk in bytes\n")
    f.close()



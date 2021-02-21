#!/usr/bin/env python3
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
        palNames = [ 'Composite', 'RGB' ]
        # check palette arrays
        for p in range(2):
            if self.palettes[p] == None:
                print(f"****Error: missing {palNames[p]} palette in file '{self.palfilename}'")
                return False
            if len(self.palettes[p]) != 16:
                print(f"****Error: {palNames[p]} palette length is {len(self.palettes[p])} (should be 16) in file '{self.palfilename}'")
                return False
            for i in range(16):
                clrIdx = self.palettes[p][i]
                if clrIdx < 0 or clrIdx > 63:
                    print(f"****Error: invalid color value {clrIdx} in {palNames[p]} palette in file '{self.palfilename}'")
                    return False
        # check each tile
        numTiles = len(self.tiles)
        for i in range(numTiles):
            tile = self.tiles[i]
            if len(tile) != 128:
                print(f"****Error: invalid data length {len(tile)} (should be 128) for tile {i} in tileset '{self.tilesetfilename}'")
                return False
            for pixVal in tile:
                if pixVal < 0 or pixVal > 255:
                    print(f"****Error: invalid pixel value {pixVal} in tile {i} in tileset '{self.tilesetfilename}'")
                    return False
        # check collision table
        numMasks = len(self.masks)
        if len(self.collisionTable) != numTiles:
            print(f"****Error: Collision table length ({len(self.collisionTable)}) and number of tiles ({numTiles}) don't match in tileset '{self.tilesetfilename}'")
            return False
        for i in range(numTiles):
            collVal = self.collisionTable[i]
            if collVal < 0 or (collVal != 255 and collVal > numMasks):
                print(f"****Error: Invalid value ({collVal}) in Collision Table in tilemask '{self.tilemaskfilename}'")
                return False
        # check each mask
        for i in range(numMasks):
            mask = self.masks[i]
            if len(mask) != 128:
                print(f"****Error: invalid data length {len(mask)} (should be 128) for mask {i} in tilemask '{self.tilemaskfilename}'")
                return False
            for pixVal in mask:
                if pixVal < 0 or pixVal > 255:
                    print(f"****Error: invalid pixel value {pixVal} in mask {i} in tilemask '{self.tilemaskfilename}'")
                    return False
        return True

def SaveMatrix(tileset, section, matrix):
    if section == "palette-cmp":
        tileset.palettes[0] = matrix
    elif section == "palette-rgb":
        tileset.palettes[1] = matrix
    elif section != None:
        print(f"****Error: Invalid section '{section}' in palette file '{tileset.palfilename}'")
        sys.exit(1)
    return

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print('DynoSprite Tile Builder script')
    # get input paths
    if len(sys.argv) != 5:
        print(f'****Usage: {sys.argv[0]} <in_gfx_folder> <in_buildobj_folder> <out_cc3_folder> <out_asm_folder>')
        sys.exit(1)
    gfxdir = sys.argv[1]
    buildobjdir = sys.argv[2]
    cc3dir = sys.argv[3]
    asmdir = sys.argv[4]
    # make list of tileset and palette files found
    filelist = os.listdir(gfxdir)
    setnames = [name[7:-4] for name in filelist if len(name) >= 15 and name[:7] == 'tileset' and name[7:9].isdigit() and name[-4:].lower() == ".txt"]
    setnames.sort()
    print(f'    Found {len(setnames)} tilesets')
    # parse each tileset/palette file pair
    tilesets = []
    for tilesetprefix in setnames:
        tilesetfilename = f'tileset{tilesetprefix}.txt'
        tilemaskfilename = f"tilemask{tilesetprefix}.txt"
        palettefilename = f"palette{tilesetprefix}.txt"
        if not os.path.exists(os.path.join(gfxdir, palettefilename)):
            print(f"****Error: Matching palette file '{palettefilename}' not found!")
            sys.exit(1)
        if not os.path.exists(os.path.join(gfxdir, tilemaskfilename)):
            print(f"****Error: Matching tilemask file '{tilemaskfilename}' not found!")
            sys.exit(1)
        mode = None
        curSet = Tileset(palettefilename, tilesetfilename, tilemaskfilename)
        # load palettes
        f = open(os.path.join(gfxdir, palettefilename)).read()
        matrix = [ ]
        for line in f.split('\n'):
            # remove comments and whitespace from line
            pivot = line.find('*')
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
        f = open(os.path.join(gfxdir, tilesetfilename)).read()
        matrix = [ ]
        for line in f.split('\n'):
            # remove comments and whitespace from line
            pivot = line.find('*')
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
                continue
            # handle tile pixel values (hex)
            pix = ''.join(line.split())
            if (len(pix) & 1) == 1:
                print(f"****Error: invalid tile pixel line length ({len(pix)}) in tileset '{filename}'")
                sys.exit(1)
            for i in range(0, len(pix), 2):
                v = int(pix[i:i+2], 16)
                matrix.append(v)
            if len(matrix) == 128:
                curSet.tiles.append(matrix)
                matrix = [ ]
        # load masks
        f = open(os.path.join(gfxdir, tilemaskfilename)).read()
        matrix = [ ]
        for line in f.split('\n'):
            # remove comments and whitespace from line
            pivot = line.find('*')
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
                continue
            # handle collision table
            if curSet.collisionTable is None:
                curSet.collisionTable = [ int(n.strip()) for n in line.split(',') ]
                continue
            # handle tile mask values (hex)
            pix = ''.join(line.split())
            if (len(pix) & 1) == 1:
                print(f"****Error: invalid tile mask line length ({len(pix)}) in tilemask '{tilemaskfilename}'")
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
    print(f'    Found a total of {totalTiles} tiles')
    # write out the data file
    f = open(os.path.join(cc3dir, 'TILES.DAT'), 'wb')
    compressedTilesetLength = [ ]
    for curSet in tilesets:
        for pal in curSet.palettes:
            for i in range(16):
                f.write(bytes([pal[i]]))
        rawData = b''
        for i in range(len(curSet.collisionTable)):
            rawData += bytes([curSet.collisionTable[i]])
        for tile in curSet.tiles:
            for i in range(128):
                rawData += bytes([tile[i]])
        for mask in curSet.masks:
            for i in range(128):
                rawData += bytes([mask[i]])
        comp = Compressor(rawData)
        zipData = comp.Deflate(bPrintInfo=False, bUseGzip=True)
        compressedTilesetLength.append(len(zipData))
        f.write(zipData)
    f.close()
    # write tile directory table to include in DynoSprite core
    f = open(os.path.join(asmdir, 'gamedir-tiles.asm'), 'w')
    f.write('Gamedir_Tiles\n')
    s = str(len(tilesets))
    f.write((' ' * 24) + 'fcb     ' + s + (' ' * (16 - len(s))) + '* number of tilesets\n')
    for i in range(len(tilesets)):
        f.write((' ' * 24) + '* ' + tilesets[i].tilesetfilename + '\n')
        s = str(tilesets[i].number)
        f.write((' ' * 24) + 'fcb     ' + s + (' ' * (16-len(s))) + '* tileset number\n')
        s = str(len(tilesets[i].tiles))
        f.write((' ' * 24) + 'fcb     ' + s + (' ' * (16-len(s))) + '* number of tiles in tileset\n')
        s = str(len(tilesets[i].masks))
        f.write((' ' * 24) + 'fcb     ' + s + (' ' * (16-len(s))) + '* number of masks in tilemask\n')
        s = str(compressedTilesetLength[i])
        f.write((' ' * 24) + 'fdb     ' + s + (' ' * (16-len(s))) + '* compressed tileset size on disk in bytes\n')
    f.close()



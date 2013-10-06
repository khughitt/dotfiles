#!/usr/bin/env python
#-*- coding:utf-8 -*-
"""
A simple Python script to generate a tracklist including BPM for a Brasero
CD save file.

Keith Hughitt (keith.hughitt@gmail.com)
2013/10/06
"""
import sys
import os
import subprocess
from urllib.parse import unquote
from xml.etree.ElementTree import ElementTree

def main():
    """Main"""
    tree = ElementTree()

    # Make sure valid filepath specified
    input_file = sys.argv[1]
    if not os.path.isfile(input_file):
        sys.exit("Invalid filepath specified")

    # Otherwise parse XML
    tree.parse(input_file)

    songs = tree.getiterator("audio")

    # Iterate through songs and print info
    for song in songs:
        # BPM
        filepath = unquote(unquote(song.find("uri").text).replace('file://', ''))
        ps = subprocess.Popen(["sox", filepath, "-t", "raw", "-r", "44100", 
                               "-e", "float", "-c", "1", "-"], 
                               stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL)
        output = subprocess.check_output(('bpm'), stdin=ps.stdout)
        bpm = output.decode().strip()

        # Title and artist
        artist = unquote(song.find("artist").text)
        title = unquote(song.find("title").text)

        # Output song info
        print("%s - %s (**%s**)" % (artist, title, bpm))

if __name__ == "__main__":
    if len(sys.argv) != 2:
         print("Example usage:\n")
         print("brasero_labeler.py cd1.xml")
         sys.exit()

    sys.exit(main())

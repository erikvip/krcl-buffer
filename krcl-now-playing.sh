#!/bin/bash
sqlite3 krcl-playlist.sqlite3 'select * from playlist order by start desc limit 1'

#!/bin/bash
sqlite3 db/krcl-playlist.sqlite3 'select * from playlist order by start desc limit 1'

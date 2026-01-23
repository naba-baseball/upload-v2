# Plan: Handle different ootp versions

Out Of the Park Baseball can have subtly different website formats when new versions come out. We'll want to account for this.


we know of only one format today

## Known Format 1 (a.k.a OOTP 23)

the game exports a reports.tar.gz file.
The file structure within looks like this:

- news/
    - html/
        - index.html
        - styles.css
        - teams/
        - images/
        - leagues/
        - scripts/
            - sorttable.js
        - players/
        - game_logs/
        - coaches/
        - box_scores/

all the folders are filled with html files, except for the ones detailed above.

We call it OOTP 23 because thats the earliest game version I've seen this format.

## Requirements

We need a "router" for each format, or some kind of routing rules. For our Known Format 1, it should route `ebc.nabaleague.com` to `news/html/index.html`. Essentially, it should prepend `news/html` onto every request when searching the file system.

This should be inserted into our routing layer.

When we have more than one format, we should autodetect the format on extraction. However, we'll just assume all sites are format 1 for now.
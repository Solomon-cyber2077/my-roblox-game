# soundscope

Measures every number in a sound and compares it with target profiles (streaming, broadcast, film, game and
house Roblox targets) or with any reference sound you like. Needs `pip install numpy scipy soundfile`.

```
python tools/soundscope/soundscope.py analyze sounds/            # every metric, any wav/flac/ogg/mp3
python tools/soundscope/soundscope.py compare hit.ogg --to roblox-impact --html report.html
python tools/soundscope/soundscope.py compare mine.wav --to film_clip.wav   # a reference file is a target too
python tools/soundscope/soundscope.py profile make horror-ref refs/         # turn reference works into a profile
python tools/soundscope/soundscope.py profile list | show <name>
python tools/soundscope/soundscope.py play hit.wav
```

Metrics: loudness (integrated, momentary, short-term, LRA per BS.1770 / EBU R128), true and sample peak, RMS,
crest, PLR, dynamic range, noise floor, clipping, DC offset, attack, tail, leading/trailing silence, loop seam,
spectral centroid, rolloff, flatness, seven band shares, stereo correlation/width/balance/mono drop, tempo,
onset rate and pitch. Each failed target prints a fix ("lower gain by 3.2 dB", "trim the start 40 ms").

Built-in profiles live in `profiles.json`; `kind: house` ones are our own targets, not official specs.
Profiles made with `profile make` are saved to `profiles/<name>.json`.

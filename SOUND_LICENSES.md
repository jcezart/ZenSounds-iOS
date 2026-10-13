# ZenSounds sound licenses

License verification date: **2026-10-13**.

All files listed below were published under [Creative Commons CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). CC0 permits copying, modification, commercial use, and redistribution without attribution. Attribution and source records are nevertheless retained here for provenance and auditability.

The integrated files are Freesound's high-quality MP3 previews of the identified uploads. They contain the complete recordings, are distributed by Freesound from its CDN, and inherit the source recording's CC0 dedication. No claim is made that the recordings were captured at the biblical locations; the app presents them as inspired soundscapes.

## GalileeWaves.mp3

- Original file: `Gentle waves on a lake.wav`
- Author/uploader: TheFlyFishingFilmmaker
- Original page: https://freesound.org/people/TheFlyFishingFilmmaker/sounds/614299/
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- License verified: 2026-10-13
- Integrated file: `ZenSounds/Resources/Audio/GalileeWaves.mp3`
- Commercial-use note: the individual file page explicitly identifies CC0 and permits commercial copying, modification, and distribution. The recording is described as gentle lake waves in eastern Washington; ZenSounds labels it as an inspired Galilee setting, not an authentic recording from the Sea of Galilee.

## MeadowSheep.mp3

- Original file: `sheep bleat outdoors.wav`
- Author/uploader: Yuval
- Original page: https://freesound.org/people/Yuval/sounds/210511/
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- License verified: 2026-10-13
- Integrated file: `ZenSounds/Resources/Audio/MeadowSheep.mp3`
- Commercial-use note: the individual file page explicitly identifies CC0. The isolated outdoor sheep layer is intentionally mixed at a low preset level to keep occasional bleats unobtrusive.

## OliveGrove.mp3

- Original file: `forest boreal light wind breeze through leaves +close loud birds.flac`
- Author/uploader: kyles
- Original page: https://freesound.org/people/kyles/sounds/637563/
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- License verified: 2026-10-13
- Integrated file: `ZenSounds/Resources/Audio/OliveGrove.mp3`
- Commercial-use note: the individual file page explicitly identifies CC0. The app describes this as an olive-garden-inspired environment, not a recording made in Gethsemane.

## MorningBirds.mp3

- Original file: `Morning Birds.wav`
- Author/uploader: nick121087
- Original page: https://freesound.org/people/nick121087/sounds/342462/
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- License verified: 2026-10-13
- Integrated file: `ZenSounds/Resources/Audio/MorningBirds.mp3`
- Commercial-use note: the individual file page explicitly identifies CC0. It is used both as an individual ambience and as a low-volume distant-bird layer in presets.

## NightCrickets.mp3

- Original file: `Crickets At Night - Clean sound.wav`
- Author/uploader: Defelozedd94
- Original page: https://freesound.org/people/Defelozedd94/sounds/522298/
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- License verified: 2026-10-13
- Integrated file: `ZenSounds/Resources/Audio/NightCrickets.mp3`
- Commercial-use note: the individual file page explicitly identifies CC0. The uploader describes it as their own garden recording with noise reduction; it provides the night layer for the Bethlehem-inspired preset.

## Artwork

Five original artwork images were generated specifically for ZenSounds with OpenAI's built-in image-generation tool on 2026-10-13. No third-party photographs, logos, people, or protected characters were supplied as references. Under the applicable OpenAI terms, as between the user and OpenAI and to the extent permitted by law, the user owns the generated output. The app may therefore bundle and commercially distribute these outputs; the user remains responsible for final review of the output and its use.

Terms: https://openai.com/policies/row-terms-of-use/

Integrated artwork:

- `GalileeWaves.jpg`: calm freshwater shoreline with gentle waves and distant hills at warm dawn.
- `MeadowSheep.jpg`: peaceful sheep grazing in a green pastoral meadow at sunrise.
- `OliveGrove.jpg`: contemplative path through mature olive trees in soft golden light.
- `MorningBirds.jpg`: quiet meadow and tree line at sunrise with a few birds.
- `NightCrickets.jpg`: moonlit rural meadow beneath an indigo night sky.

Each source was generated at a square aspect ratio, reviewed visually, resized to 1024 × 1024, and encoded as JPEG at quality 88 for efficient offline use. The same named asset is shared by the individual sound row and player. Official Biblical Soundscapes map to a thematically matching one of these assets, ensuring that their library card, full player hero, and compact player use the same visual identity.

## Technical preparation and validation status

- Source delivery: Freesound high-quality MP3 preview, retained as MP3 for compatibility with the existing `LoopingPlayer` resource lookup and `scheduleFile()` architecture.
- Files remain offline and bundled with the application.
- The selected recordings are long enough to reduce repetition: approximately 175.5 s, 30.2 s, 79.1 s, 100.0 s, and 169.0 s respectively.
- No destructive dynamics processing or synthetic historical claims were introduced.
- Container integrity, duration, bitrate, and decodability were checked with macOS `afinfo` and the Xcode build pipeline.
- Seam transitions still require listening tests on a physical iPhone with headphones. A successful build or waveform/container check is not evidence that a loop is perceptually seamless.

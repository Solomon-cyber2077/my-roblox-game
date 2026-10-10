# Train exterior: references and licences

## Roblox documentation (limits verified 2026-10-09)

| Link | What it informed |
|---|---|
| https://create.roblox.com/docs/art/modeling/specifications | 20,000 triangles per mesh cap; watertight, no zero-thickness, avoid n-gons |
| https://create.roblox.com/docs/art/modeling/texture-specifications | 4096 max texture; ~1024 for a 20-stud object (car atlases 2048, kit 1024); OpenGL tangent normals; single-channel roughness/metalness |
| https://create.roblox.com/docs/art/modeling/surface-appearance | AlphaMode Overlay shows the MeshPart colour under the colour map's alpha: how the Livery cosmetic keeps tinting |
| https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance | texture properties are not script-writable at runtime, so templates come in through Rojo (a plugin may set them) |
| https://create.roblox.com/docs/reference/engine/classes/AssetService | `CreateMeshPartAsync` makes MeshParts from uploaded ids at runtime (plugins, so Rojo, cannot write MeshId) |
| https://create.roblox.com/docs/cloud/guides/usage-assets | Open Cloud model upload (not used: no API key; the 3D Importer was used instead) |
| https://devforum.roblox.com/t/does-roblox-use-mesh-instancing/399564 | same mesh + same textures instance into one draw call: shared kit meshes and one atlas per car |
| https://devforum.roblox.com/t/the-current-thread-cannot-write-meshid-lacking-capability-notaccessible/3306176 | MeshId is not writable from plugins or scripts; use CreateMeshPartAsync |

## Railway reference (inspiration only, nothing copied)

| Link | What it informed |
|---|---|
| https://thelondoneconomic.com/?p=67061 | gold-leaf lining on a varnished 19th-century saloon: lining as fine gilt beads, chipped not bright |
| https://www.rmweb.co.uk/forums/topic/148464-coach-livery-query/ | "old gold" lining reads yellow-brown, not metallic yellow: the gilt palette |
| https://www.rmweb.co.uk/forums/topic/114157-clerestory-coach-roof-boards/ | clerestory roof boards and lamp-tops on the roof deck |
| https://warwickshirerailways.com/lms/mrwj123b.htm | panelled carriage sides with waist rail and eaves panels; side lookouts on brake vehicles |
| https://railsofsheffield.com/products/rapido-987011-lnwr-d17b-brake-ncb-no-1 | guard's van lookout (ducket) idea for the Guard's van silhouette |
| https://en.wikipedia.org/wiki/Victorian_Railways_wooden_bogie_passenger_carriages | buffers, screw couplings and steel underframes under timber bodies |
| https://www.westernthunder.co.uk/threads/gresley-carriages-in-detail.9809/page-4 | footboards/steps only under the doors, solebar and underframe detail |

## Assets made for this work (all own work)

| Asset | Made with | Licence |
|---|---|---|
| every train mesh (assets/train/*.fbx, *.blend) | Blender 5.2, `tools/trainshell/*.py` | own work |
| colour/normal/roughness/metalness atlases | Cycles bakes + NumPy wear painting in `bake.py` | own work, procedural (no photo textures) |
| name boards (`*_sign.png`) | Pillow, `make_sign.py`, Merriweather from Roblox's bundled fonts | Merriweather: SIL Open Font License 1.1 |

No third-party textures, models or fonts beyond the OFL font above.

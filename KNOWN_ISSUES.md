# Known issues

## FNAF 1 camera panning and fan animation

**Status:** unresolved. The default Wine setup starts the game and is playable, but it does not match the smooth movement in the [reference gameplay video](https://www.youtube.com/watch?v=jPzHagA1pls).

On one Apple M4 Mac using Wine 10.0 (Sikarugir), the controls responded and audio played at the expected speed. The player reported that the camera responds at full speed, but the left-to-right view change is choppy; the office fan also appears to move slower and less smoothly than in the reference. The cause has not been isolated. WineD3D logs show repeated OpenGL framebuffer errors during rendering, which may be related but have not been proven to cause the stutter.

### Renderer tests

| Configuration | Result |
| --- | --- |
| Wine's default OpenGL/WineD3D renderer | Playable; camera panning and fan animation remain choppy. This is the current fallback. |
| CnC-DDraw 7.1.0, windowed OpenGL, 60 FPS with VSync | No noticeable improvement; not kept in the launcher. |
| DXVK-Sikarugir 2.3 through a Direct3D 9 override | Worse; the player could not get into a game. Reverted. |
| Wine's Vulkan renderer with `ffp_hlsl=1` | Major title-screen stutters; the player could not get into a game. Reverted. |
| Wine's OpenGL renderer with `ffp_hlsl=1` | White flashes and white boxes. Reverted. |

The last three settings are not enabled by the FNAF 1 launcher. CnC-DDraw was also removed from that launcher after it made no visible difference. Its upstream documentation describes it as a DirectDraw reimplementation and says it does not support Direct3D games; see the [CnC-DDraw project](https://github.com/FunkyFr3sh/cnc-ddraw).

Pull requests that improve smooth panning are welcome. A useful comparison should note the Mac chip, macOS version, Wine build, renderer settings, and whether the fan and camera pan improve in the same scene. Do not attach game files, assets, or saves.

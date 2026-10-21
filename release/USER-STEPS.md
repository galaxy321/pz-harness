# Your steps at the PC: check Benchmark Save, then upload (PZ Harness 1.13.43)

Use `workshop-1.13.43-art.zip` (sha256 `50e56e4d9a66b10c4986dbb25651022761ad2a0845e706922c826b05bfe272d9`). It is only the carrier; never upload the zip to Steam.

## A. Set up (5 min)
1. Close the game. Unzip the zip into `C:\Users\tony6\Zomboid\Workshop\` so you have `Workshop\PZHarness\` and `Workshop\PZHarnessDevAddon\`.
2. Move these folders out of `C:\Users\tony6\Zomboid\mods\` (same ids would clash): `TestGround`, `TestGroundBridge`, `TestGroundAutorun`, `TestGroundCapture`, `TestGroundMemory`.
3. Start the game. In MODS (main menu) enable **PZ Harness** and **PZ Harness: Capture** only (ZombieBuddy is already on). Accept ZombieBuddy's prompt for the Capture jar if it asks.

## B. Check Benchmark Save (about 10 min)
1. Main menu, bottom left: click **Benchmark Save**.
2. Pick one of your own saves (not "New vanilla save"), then click **Quick test (about 5 min)**. Leave the game window in front.
3. Watch the run. At the end you should see the end screen with the key figures, a closing countdown, and a button to pause the countdown. Press the pause button once and check the countdown stops.
4. Let it close, start the game again, and look at the Benchmark Save list: the throwaway copy should be gone, and your save untouched.
5. Look at the newest `Zomboid\Lua\TestGround_quick_*.txt`: the report should say it tested your chosen save and show "PZ Harness" 1.13.43.
Tell me what looked wrong, if anything. Anything wrong in 2 to 5 holds the upload.

## C. Upload (about 15 min)
1. Main menu > **Workshop** > **Create and update items**. The two items appear. Accept Steam's Workshop agreement if it asks.
2. Upload **PZ Harness** first. Leave visibility **Unlisted**.
3. Upload **PZ Harness Dev Add-on** second. Also Unlisted.
4. After each upload the game writes `id=<number>` into that item's `workshop.txt` (in `Zomboid\Workshop\<item>\`). Send me both numbers (or that file), so later updates keep the same item.
5. On Steam, add the gallery how-to image to PZ Harness (`release\overlay\items\PZHarness\gallery\howto-benchmark-save-1920.png`) and, on the Dev Add-on page, add PZ Harness as a required item.
6. Subscribe from a clean mod list, check both load, then switch both to Public.

## D. Put things back
Delete `Zomboid\Workshop\PZHarness` and `PZHarnessDevAddon` after the id is saved (the game keeps the subscription copy), and move your dev mods back into `Zomboid\mods\`.
